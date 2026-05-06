<template>
  <div class="product-detail-page">
    <Header />

    <div class="detail-container" v-loading="loading">
      <template v-if="product">
        <!-- 商品主要信息 -->
        <div class="main-content">
          <!-- 左侧：图片轮播 -->
          <div class="image-section">
            <el-carousel height="400px" indicator-position="outside">
              <el-carousel-item v-for="(image, index) in product.images" :key="index">
                <el-image :src="image" fit="contain" class="carousel-image" />
              </el-carousel-item>
            </el-carousel>
          </div>

          <!-- 右侧：商品信息 -->
          <div class="info-section">
            <h1 class="product-title">{{ product.title }}</h1>

            <div class="price-box">
              <span class="price">¥{{ product.price }}</span>
              <span class="original-price" v-if="product.originalPrice">¥{{ product.originalPrice }}</span>
            </div>

            <div class="product-meta">
              <el-row :gutter="20">
                <el-col :span="12">
                  <div class="meta-item">
                    <span class="label">成色：</span>
                    <el-tag>{{ product.condition }}</el-tag>
                  </div>
                </el-col>
                <el-col :span="12">
                  <div class="meta-item">
                    <span class="label">位置：</span>
                    <span>{{ product.location }}</span>
                  </div>
                </el-col>
                <el-col :span="12">
                  <div class="meta-item">
                    <span class="label">浏览量：</span>
                    <span>{{ product.viewCount }}</span>
                  </div>
                </el-col>
                <el-col :span="12">
                  <div class="meta-item">
                    <span class="label">收藏量：</span>
                    <span>{{ product.favoriteCount }}</span>
                  </div>
                </el-col>
              </el-row>
            </div>

            <!-- 卖家信息 -->
            <el-card class="seller-card" shadow="hover">
              <div class="seller-info">
                <el-avatar :size="50" :src="product.seller?.avatar" />
                <div class="seller-detail">
                  <div class="seller-name">{{ product.seller?.username }}</div>
                  <div class="seller-credit">
                    <el-icon><Star /></el-icon>
                    <span>信用分：{{ product.seller?.creditScore || 0 }}</span>
                  </div>
                </div>
              </div>
            </el-card>

            <!-- 操作按钮 -->
            <div class="action-buttons">
              <el-button type="primary" size="large" @click="handleBuy">
                立即购买
              </el-button>
              <el-button size="large" @click="handleContact">
                <el-icon><ChatDotRound /></el-icon>
                联系卖家
              </el-button>
              <el-button
                :type="isFavorite ? 'danger' : 'default'"
                size="large"
                @click="handleFavorite"
              >
                <el-icon><Star /></el-icon>
                {{ isFavorite ? '取消收藏' : '收藏' }}
              </el-button>
            </div>
          </div>
        </div>

        <!-- 商品详情描述 -->
        <el-card class="description-card">
          <template #header>
            <h3>商品详情</h3>
          </template>
          <div class="description-content" v-html="product.description"></div>
        </el-card>

        <!-- 评价列表 -->
        <el-card class="reviews-card">
          <template #header>
            <h3>商品评价</h3>
          </template>
          <div class="reviews-list">
            <div v-if="reviews.length === 0" class="empty-reviews">
              暂无评价
            </div>
            <div v-else>
              <div v-for="review in reviews" :key="review.id" class="review-item">
                <div class="review-header">
                  <el-avatar :size="40" :src="review.user?.avatar" />
                  <div class="review-user">
                    <div class="user-name">{{ review.user?.username }}</div>
                    <el-rate v-model="review.rating" disabled size="small" />
                  </div>
                  <span class="review-time">{{ review.createTime }}</span>
                </div>
                <div class="review-content">{{ review.content }}</div>
              </div>
              <el-pagination
                v-model:current-page="reviewPage"
                :page-size="reviewSize"
                :total="reviewTotal"
                layout="prev, pager, next"
                @current-change="loadReviews"
              />
            </div>
          </div>
        </el-card>

        <!-- 相似商品推荐 -->
        <el-card class="similar-card">
          <template #header>
            <h3>相似商品推荐</h3>
          </template>
          <el-row :gutter="20">
            <el-col :span="6" v-for="item in similarProducts" :key="item.id">
              <div class="similar-item" @click="goToProduct(item.id)">
                <el-image :src="item.images[0]" fit="cover" class="similar-image" />
                <div class="similar-title">{{ item.title }}</div>
                <div class="similar-price">¥{{ item.price }}</div>
              </div>
            </el-col>
          </el-row>
        </el-card>
      </template>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { Star, ChatDotRound } from '@element-plus/icons-vue'
import Header from '@/components/Header.vue'
import { getProductDetail } from '@/api/product'
import { addFavorite, removeFavorite, checkFavorite } from '@/api/favorite'
import { getProductReviews } from '@/api/review'

const route = useRoute()
const router = useRouter()

const loading = ref(false)
const product = ref(null)
const isFavorite = ref(false)
const reviews = ref([])
const reviewPage = ref(1)
const reviewSize = ref(10)
const reviewTotal = ref(0)
const similarProducts = ref([])

// 加载商品详情
const loadProductDetail = async () => {
  loading.value = true
  try {
    const res = await getProductDetail(route.params.id)
    product.value = res

    // 检查是否已收藏
    checkIsFavorite()

    // 加载评价
    loadReviews()

    // 加载相似商品
    loadSimilarProducts()
  } catch (error) {
    ElMessage.error('加载商品详情失败')
  } finally {
    loading.value = false
  }
}

// 检查是否已收藏
const checkIsFavorite = async () => {
  try {
    const res = await checkFavorite(route.params.id)
    isFavorite.value = res
  } catch (error) {
    console.error('检查收藏状态失败', error)
  }
}

// 收藏/取消收藏
const handleFavorite = async () => {
  try {
    if (isFavorite.value) {
      await removeFavorite(route.params.id)
      ElMessage.success('取消收藏成功')
      isFavorite.value = false
    } else {
      await addFavorite(route.params.id)
      ElMessage.success('收藏成功')
      isFavorite.value = true
    }
  } catch (error) {
    ElMessage.error('操作失败')
  }
}

// 立即购买
const handleBuy = () => {
  router.push({
    path: '/order-confirm',
    query: { productId: route.params.id }
  })
}

// 联系卖家
const handleContact = () => {
  router.push({
    path: '/chat',
    query: { sellerId: product.value.seller?.id }
  })
}

// 加载评价列表
const loadReviews = async () => {
  try {
    const res = await getProductReviews(route.params.id, reviewPage.value, reviewSize.value)
    reviews.value = res.records || res.list || []
    reviewTotal.value = res.total || 0
  } catch (error) {
    console.error('加载评价失败', error)
  }
}

// 加载相似商品（同分类商品）
const loadSimilarProducts = async () => {
  try {
    if (!product.value?.categoryId) return
    const { getProductList } = await import('@/api/product')
    const listRes = await getProductList({ categoryId: product.value.categoryId, page: 1, size: 4 })
    similarProducts.value = (listRes.records || listRes.list || []).filter(p => p.id !== product.value.id).slice(0, 4)
  } catch (error) {
    console.error('加载相似商品失败', error)
  }
}

// 跳转到商品详情
const goToProduct = (id) => {
  router.push(`/product/${id}`)
  loadProductDetail()
}

onMounted(() => {
  loadProductDetail()
})
</script>

<style scoped>
.product-detail-page {
  min-height: 100vh;
  background: #f5f5f5;
}

.detail-container {
  max-width: 1200px;
  margin: 20px auto;
  padding: 0 20px;
}

.main-content {
  display: flex;
  gap: 20px;
  margin-bottom: 20px;
}

.image-section {
  flex: 1;
  background: #fff;
  padding: 20px;
  border-radius: 8px;
}

.carousel-image {
  width: 100%;
  height: 100%;
}

.info-section {
  width: 400px;
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.product-title {
  font-size: 24px;
  font-weight: bold;
  margin: 0;
  padding: 20px;
  background: #fff;
  border-radius: 8px;
}

.price-box {
  padding: 20px;
  background: #fff;
  border-radius: 8px;
}

.price {
  font-size: 32px;
  color: #ff4d4f;
  font-weight: bold;
}

.original-price {
  font-size: 18px;
  color: #999;
  text-decoration: line-through;
  margin-left: 10px;
}

.product-meta {
  padding: 20px;
  background: #fff;
  border-radius: 8px;
}

.meta-item {
  margin-bottom: 10px;
}

.meta-item .label {
  color: #666;
}

.seller-card {
  margin-bottom: 20px;
}

.seller-info {
  display: flex;
  align-items: center;
  gap: 15px;
}

.seller-detail {
  flex: 1;
}

.seller-name {
  font-size: 16px;
  font-weight: bold;
  margin-bottom: 5px;
}

.seller-credit {
  display: flex;
  align-items: center;
  gap: 5px;
  color: #ff9800;
}

.action-buttons {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.action-buttons .el-button {
  width: 100%;
}

.description-card,
.reviews-card,
.similar-card {
  margin-bottom: 20px;
}

.description-content {
  line-height: 1.8;
  white-space: pre-wrap;
}

.reviews-list {
  min-height: 200px;
}

.empty-reviews {
  text-align: center;
  padding: 40px;
  color: #999;
}

.review-item {
  padding: 20px 0;
  border-bottom: 1px solid #f0f0f0;
}

.review-item:last-child {
  border-bottom: none;
}

.review-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 10px;
}

.review-user {
  flex: 1;
}

.user-name {
  font-weight: bold;
  margin-bottom: 5px;
}

.review-time {
  color: #999;
  font-size: 14px;
}

.review-content {
  padding-left: 50px;
  line-height: 1.6;
}

.similar-item {
  cursor: pointer;
  transition: transform 0.3s;
}

.similar-item:hover {
  transform: translateY(-5px);
}

.similar-image {
  width: 100%;
  height: 200px;
  border-radius: 8px;
  margin-bottom: 10px;
}

.similar-title {
  font-size: 14px;
  margin-bottom: 5px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.similar-price {
  color: #ff4d4f;
  font-weight: bold;
}

@media (max-width: 768px) {
  .main-content {
    flex-direction: column;
  }

  .info-section {
    width: 100%;
  }
}
</style>

