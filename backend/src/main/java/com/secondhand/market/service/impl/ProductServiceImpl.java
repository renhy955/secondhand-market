package com.secondhand.market.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.secondhand.market.common.BusinessException;
import com.secondhand.market.constants.ProductStatus;
import com.secondhand.market.dto.ProductPublishRequest;
import com.secondhand.market.dto.ProductQueryRequest;
import com.secondhand.market.entity.Product;
import com.secondhand.market.entity.ProductImage;
import com.secondhand.market.entity.User;
import com.secondhand.market.mapper.ProductImageMapper;
import com.secondhand.market.mapper.ProductMapper;
import com.secondhand.market.mapper.UserMapper;
import com.secondhand.market.service.ProductService;
import com.secondhand.market.vo.ProductListVO;
import com.secondhand.market.vo.ProductVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.BeanUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.util.List;
import java.util.stream.Collectors;

/**
 * 商品服务实现类
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ProductServiceImpl implements ProductService {

    private final ProductMapper productMapper;
    private final ProductImageMapper productImageMapper;
    private final UserMapper userMapper;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Long publishProduct(ProductPublishRequest request, Long userId) {
        Product product = new Product();
        BeanUtils.copyProperties(request, product);
        product.setUserId(userId);
        product.setStatus(ProductStatus.ON_SHELF); // 在售
        product.setViewCount(0);

        productMapper.insert(product);
        log.info("商品发布成功: productId={}, userId={}", product.getId(), userId);

        saveProductImages(product.getId(), request.getImages());

        return product.getId();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void updateProduct(Long productId, ProductPublishRequest request, Long userId) {
        Product product = productMapper.selectById(productId);
        if (product == null) {
            throw new BusinessException(404, "商品不存在");
        }
        if (!product.getUserId().equals(userId)) {
            throw new BusinessException(403, "无权限编辑此商品");
        }

        BeanUtils.copyProperties(request, product);
        productMapper.updateById(product);
        log.info("商品更新成功: productId={}, userId={}", productId, userId);

        // 删除旧的图片，插入新的
        LambdaQueryWrapper<ProductImage> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(ProductImage::getProductId, productId);
        productImageMapper.delete(wrapper);

        saveProductImages(productId, request.getImages());
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void deleteProduct(Long productId, Long userId) {
        Product product = productMapper.selectById(productId);
        if (product == null) {
            throw new BusinessException(404, "商品不存在");
        }
        if (!product.getUserId().equals(userId)) {
            throw new BusinessException(403, "无权限删除此商品");
        }

        productMapper.deleteById(productId);

        // 删除商品图片
        LambdaQueryWrapper<ProductImage> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(ProductImage::getProductId, productId);
        productImageMapper.delete(wrapper);
        log.info("商品删除成功: productId={}, userId={}", productId, userId);
    }

    @Override
    public void onShelf(Long productId, Long userId) {
        updateProductStatus(productId, userId, 1);
    }

    @Override
    public void offShelf(Long productId, Long userId) {
        updateProductStatus(productId, userId, 0);
    }

    @Override
    public Page<ProductListVO> queryProducts(ProductQueryRequest request) {
        Page<Product> page = new Page<>(request.getPage(), request.getSize());

        LambdaQueryWrapper<Product> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Product::getStatus, 1); // 只查询在售商品

        if (StringUtils.hasText(request.getKeyword())) {
            wrapper.and(w -> w.like(Product::getTitle, request.getKeyword())
                    .or()
                    .like(Product::getDescription, request.getKeyword()));
        }

        if (request.getCategoryId() != null) {
            wrapper.eq(Product::getCategoryId, request.getCategoryId());
        }

        if (request.getMinPrice() != null) {
            wrapper.ge(Product::getPrice, request.getMinPrice());
        }

        if (request.getMaxPrice() != null) {
            wrapper.le(Product::getPrice, request.getMaxPrice());
        }

        if (StringUtils.hasText(request.getConditionLevel())) {
            wrapper.eq(Product::getConditionLevel, request.getConditionLevel());
        }

        if (StringUtils.hasText(request.getProvince())) {
            wrapper.eq(Product::getProvince, request.getProvince());
        }

        if (StringUtils.hasText(request.getCity())) {
            wrapper.eq(Product::getCity, request.getCity());
        }

        wrapper.orderByDesc(Product::getCreateTime);

        Page<Product> productPage = productMapper.selectPage(page, wrapper);

        Page<ProductListVO> voPage = new Page<>(productPage.getCurrent(), productPage.getSize(), productPage.getTotal());
        List<ProductListVO> voList = productPage.getRecords().stream().map(product -> {
            ProductListVO vo = new ProductListVO();
            BeanUtils.copyProperties(product, vo);

            LambdaQueryWrapper<ProductImage> imageWrapper = new LambdaQueryWrapper<>();
            imageWrapper.eq(ProductImage::getProductId, product.getId())
                    .orderByAsc(ProductImage::getSortOrder)
                    .last("LIMIT 1");
            ProductImage firstImage = productImageMapper.selectOne(imageWrapper);
            if (firstImage != null) {
                vo.setFirstImage(firstImage.getImageUrl());
            }

            return vo;
        }).collect(Collectors.toList());

        voPage.setRecords(voList);
        return voPage;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public ProductVO getProductDetail(Long productId) {
        Product product = productMapper.selectById(productId);
        if (product == null) {
            throw new BusinessException(404, "商品不存在");
        }

        // 原子更新浏览量（使用SQL更新而不是读取后更新，避免并发问题）
        productMapper.update(null, new LambdaUpdateWrapper<Product>()
                .eq(Product::getId, productId)
                .setSql("view_count = view_count + 1"));

        // 重新查询获取最新数据
        product = productMapper.selectById(productId);

        ProductVO vo = new ProductVO();
        BeanUtils.copyProperties(product, vo);

        // 获取商品图片列表
        LambdaQueryWrapper<ProductImage> imageWrapper = new LambdaQueryWrapper<>();
        imageWrapper.eq(ProductImage::getProductId, productId)
                .orderByAsc(ProductImage::getSortOrder);
        List<ProductImage> images = productImageMapper.selectList(imageWrapper);
        vo.setImages(images.stream().map(ProductImage::getImageUrl).collect(Collectors.toList()));

        // 获取卖家信息
        User user = userMapper.selectById(product.getUserId());
        if (user != null) {
            ProductVO.SellerInfo seller = new ProductVO.SellerInfo();
            seller.setId(user.getId());
            seller.setNickname(user.getNickname());
            seller.setAvatar(user.getAvatar());
            seller.setCreditScore(user.getCreditScore());
            vo.setSeller(seller);
        }

        return vo;
    }

    /**
     * 获取用户发布的商品列表
     */
    @Override
    public Page<ProductListVO> getUserProducts(Long userId, Integer page, Integer size) {
        Page<Product> productPage = new Page<>(page, size);

        LambdaQueryWrapper<Product> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Product::getUserId, userId)
                .eq(Product::getDeleted, 0)
                .orderByDesc(Product::getCreateTime);

        productPage = productMapper.selectPage(productPage, wrapper);

        Page<ProductListVO> voPage = new Page<>(productPage.getCurrent(), productPage.getSize(), productPage.getTotal());
        List<ProductListVO> voList = productPage.getRecords().stream().map(product -> {
            ProductListVO vo = new ProductListVO();
            BeanUtils.copyProperties(product, vo);

            // 获取第一张图片
            LambdaQueryWrapper<ProductImage> imageWrapper = new LambdaQueryWrapper<>();
            imageWrapper.eq(ProductImage::getProductId, product.getId())
                    .orderByAsc(ProductImage::getSortOrder)
                    .last("LIMIT 1");
            ProductImage firstImage = productImageMapper.selectOne(imageWrapper);
            if (firstImage != null) {
                vo.setFirstImage(firstImage.getImageUrl());
            }

            return vo;
        }).collect(Collectors.toList());

        voPage.setRecords(voList);
        return voPage;
    }

    /**
     * 保存商品图片
     */
    private void saveProductImages(Long productId, List<String> images) {
        if (images == null || images.isEmpty()) {
            return;
        }
        int order = 0;
        for (String imageUrl : images) {
            if (!StringUtils.hasText(imageUrl)) {
                continue;
            }
            ProductImage image = new ProductImage();
            image.setProductId(productId);
            image.setImageUrl(imageUrl);
            image.setSortOrder(order++);
            productImageMapper.insert(image);
        }
    }

    /**
     * 更新商品状态
     */
    private void updateProductStatus(Long productId, Long userId, Integer status) {
        Product product = productMapper.selectById(productId);
        if (product == null) {
            throw new BusinessException(404, "商品不存在");
        }
        if (!product.getUserId().equals(userId)) {
            throw new BusinessException(403, "无权限操作此商品");
        }

        product.setStatus(status);
        productMapper.updateById(product);
        log.info("商品状态更新成功: productId={}, status={}, userId={}", productId, status, userId);
    }
}