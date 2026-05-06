-- 二手交易平台数据库初始化脚本
-- 数据库版本: MySQL 8.0+
-- 字符集: utf8mb4

CREATE DATABASE IF NOT EXISTS secondhand_market DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE secondhand_market;

-- 1. 用户表
CREATE TABLE `user` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '用户ID',
  `username` VARCHAR(50) NOT NULL UNIQUE COMMENT '用户名',
  `password` VARCHAR(255) NOT NULL COMMENT '密码(BCrypt加密)',
  `nickname` VARCHAR(50) COMMENT '昵称',
  `avatar` VARCHAR(500) COMMENT '头像URL',
  `phone` VARCHAR(20) UNIQUE COMMENT '手机号',
  `email` VARCHAR(100) UNIQUE COMMENT '邮箱',
  `real_name` VARCHAR(50) COMMENT '真实姓名',
  `id_card` VARCHAR(18) COMMENT '身份证号',
  `is_verified` TINYINT DEFAULT 0 COMMENT '是否实名认证(0-否,1-是)',
  `credit_score` INT DEFAULT 100 COMMENT '信用分(0-100)',
  `balance` DECIMAL(10,2) DEFAULT 0.00 COMMENT '账户余额',
  `status` TINYINT DEFAULT 1 COMMENT '状态(0-冻结,1-正常,2-封禁)',
  `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  INDEX idx_phone (`phone`),
  INDEX idx_email (`email`),
  INDEX idx_status (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

-- 2. 收货地址表
CREATE TABLE `user_address` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '地址ID',
  `user_id` BIGINT NOT NULL COMMENT '用户ID',
  `receiver_name` VARCHAR(50) NOT NULL COMMENT '收货人姓名',
  `receiver_phone` VARCHAR(20) NOT NULL COMMENT '收货人电话',
  `province` VARCHAR(50) NOT NULL COMMENT '省份',
  `city` VARCHAR(50) NOT NULL COMMENT '城市',
  `district` VARCHAR(50) NOT NULL COMMENT '区县',
  `detail_address` VARCHAR(200) NOT NULL COMMENT '详细地址',
  `is_default` TINYINT DEFAULT 0 COMMENT '是否默认地址(0-否,1-是)',
  `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  INDEX idx_user_id (`user_id`),
  FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='收货地址表';

-- 3. 商品分类表
CREATE TABLE `category` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '分类ID',
  `parent_id` BIGINT DEFAULT 0 COMMENT '父分类ID(0表示一级分类)',
  `name` VARCHAR(50) NOT NULL COMMENT '分类名称',
  `icon` VARCHAR(500) COMMENT '分类图标',
  `sort_order` INT DEFAULT 0 COMMENT '排序',
  `status` TINYINT DEFAULT 1 COMMENT '状态(0-禁用,1-启用)',
  `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  INDEX idx_parent_id (`parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品分类表';

-- 4. 商品表
CREATE TABLE `product` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '商品ID',
  `user_id` BIGINT NOT NULL COMMENT '卖家ID',
  `category_id` BIGINT NOT NULL COMMENT '分类ID',
  `title` VARCHAR(100) NOT NULL COMMENT '商品标题',
  `description` TEXT COMMENT '商品描述',
  `price` DECIMAL(10,2) NOT NULL COMMENT '商品价格',
  `stock` INT DEFAULT 1 COMMENT '库存数量',
  `condition_level` VARCHAR(20) COMMENT '成色(全新/99新/95新/9成新/8成新及以下)',
  `trade_method` VARCHAR(20) COMMENT '交易方式(仅邮寄/仅自提/都可以)',
  `province` VARCHAR(50) COMMENT '省份',
  `city` VARCHAR(50) COMMENT '城市',
  `district` VARCHAR(50) COMMENT '区县',
  `view_count` INT DEFAULT 0 COMMENT '浏览量',
  `favorite_count` INT DEFAULT 0 COMMENT '收藏数',
  `status` TINYINT DEFAULT 0 COMMENT '状态(0-待审核,1-在售,2-已售,3-已下架)',
  `deleted` TINYINT DEFAULT 0 COMMENT '逻辑删除(0-未删除,1-已删除)',
  `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  INDEX idx_user_id (`user_id`),
  INDEX idx_category_id (`category_id`),
  INDEX idx_status (`status`),
  INDEX idx_create_time (`create_time`),
  FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`category_id`) REFERENCES `category`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品表';

-- 5. 商品图片表
CREATE TABLE `product_image` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '图片ID',
  `product_id` BIGINT NOT NULL COMMENT '商品ID',
  `image_url` VARCHAR(500) NOT NULL COMMENT '图片URL',
  `sort_order` INT DEFAULT 0 COMMENT '排序',
  `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  INDEX idx_product_id (`product_id`),
  FOREIGN KEY (`product_id`) REFERENCES `product`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品图片表';

-- 6. 订单表
CREATE TABLE `order` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '订单ID',
  `order_no` VARCHAR(50) NOT NULL UNIQUE COMMENT '订单号',
  `buyer_id` BIGINT NOT NULL COMMENT '买家ID',
  `seller_id` BIGINT NOT NULL COMMENT '卖家ID',
  `product_id` BIGINT NOT NULL COMMENT '商品ID',
  `product_title` VARCHAR(100) NOT NULL COMMENT '商品标题',
  `product_image` VARCHAR(500) COMMENT '商品图片',
  `product_price` DECIMAL(10,2) NOT NULL COMMENT '商品价格',
  `quantity` INT DEFAULT 1 COMMENT '购买数量',
  `total_amount` DECIMAL(10,2) NOT NULL COMMENT '订单总额',
  `buyer_message` VARCHAR(500) COMMENT '买家留言',
  `address_id` BIGINT COMMENT '收货地址ID',
  `receiver_name` VARCHAR(50) COMMENT '收货人姓名',
  `receiver_phone` VARCHAR(20) COMMENT '收货人电话',
  `receiver_address` VARCHAR(500) COMMENT '收货地址',
  `express_company` VARCHAR(50) COMMENT '快递公司',
  `express_no` VARCHAR(50) COMMENT '快递单号',
  `status` TINYINT DEFAULT 0 COMMENT '订单状态(0-待付款,1-待发货,2-待收货,3-已完成,4-已取消,5-退款中,6-已退款)',
  `pay_time` DATETIME COMMENT '支付时间',
  `ship_time` DATETIME COMMENT '发货时间',
  `receive_time` DATETIME COMMENT '收货时间',
  `cancel_time` DATETIME COMMENT '取消时间',
  `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  INDEX idx_order_no (`order_no`),
  INDEX idx_buyer_id (`buyer_id`),
  INDEX idx_seller_id (`seller_id`),
  INDEX idx_status (`status`),
  INDEX idx_create_time (`create_time`),
  FOREIGN KEY (`buyer_id`) REFERENCES `user`(`id`),
  FOREIGN KEY (`seller_id`) REFERENCES `user`(`id`),
  FOREIGN KEY (`product_id`) REFERENCES `product`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单表';

-- 7. 支付记录表
CREATE TABLE `payment` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '支付ID',
  `order_id` BIGINT NOT NULL COMMENT '订单ID',
  `payment_no` VARCHAR(50) NOT NULL UNIQUE COMMENT '支付流水号',
  `payment_method` VARCHAR(20) NOT NULL COMMENT '支付方式(alipay/wechat/balance)',
  `amount` DECIMAL(10,2) NOT NULL COMMENT '支付金额',
  `status` TINYINT DEFAULT 0 COMMENT '支付状态(0-待支付,1-支付成功,2-支付失败)',
  `pay_time` DATETIME COMMENT '支付时间',
  `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  INDEX idx_order_id (`order_id`),
  INDEX idx_payment_no (`payment_no`),
  FOREIGN KEY (`order_id`) REFERENCES `order`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='支付记录表';

-- 8. 收藏表
CREATE TABLE `favorite` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '收藏ID',
  `user_id` BIGINT NOT NULL COMMENT '用户ID',
  `product_id` BIGINT NOT NULL COMMENT '商品ID',
  `deleted` TINYINT DEFAULT 0 COMMENT '逻辑删除(0-未删除,1-已删除)',
  `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  UNIQUE KEY uk_user_product (`user_id`, `product_id`),
  INDEX idx_user_id (`user_id`),
  INDEX idx_product_id (`product_id`),
  FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`product_id`) REFERENCES `product`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='收藏表';

-- 9. 评价表
CREATE TABLE `review` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '评价ID',
  `order_id` BIGINT NOT NULL COMMENT '订单ID',
  `product_id` BIGINT NOT NULL COMMENT '商品ID',
  `reviewer_id` BIGINT NOT NULL COMMENT '评价人ID',
  `reviewee_id` BIGINT NOT NULL COMMENT '被评价人ID',
  `seller_id` BIGINT COMMENT '卖家ID',
  `rating` INT NOT NULL COMMENT '评分(1-5星)',
  `content` TEXT COMMENT '评价内容',
  `images` VARCHAR(1000) COMMENT '评价图片(多张用逗号分隔)',
  `tags` VARCHAR(200) COMMENT '评价标签(描述相符/物流速度/服务态度)',
  `is_anonymous` TINYINT DEFAULT 0 COMMENT '是否匿名(0-否,1-是)',
  `reply_id` BIGINT COMMENT '回复ID',
  `reply_content` TEXT COMMENT '回复内容',
  `reply_time` DATETIME COMMENT '回复时间',
  `deleted` TINYINT DEFAULT 0 COMMENT '逻辑删除(0-未删除,1-已删除)',
  `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  INDEX idx_order_id (`order_id`),
  INDEX idx_product_id (`product_id`),
  INDEX idx_reviewer_id (`reviewer_id`),
  INDEX idx_reviewee_id (`reviewee_id`),
  FOREIGN KEY (`order_id`) REFERENCES `order`(`id`),
  FOREIGN KEY (`product_id`) REFERENCES `product`(`id`),
  FOREIGN KEY (`reviewer_id`) REFERENCES `user`(`id`),
  FOREIGN KEY (`reviewee_id`) REFERENCES `user`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='评价表';

-- 10. 聊天消息表
CREATE TABLE `message` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '消息ID',
  `from_user_id` BIGINT NOT NULL COMMENT '发送者ID',
  `to_user_id` BIGINT NOT NULL COMMENT '接收者ID',
  `content` TEXT NOT NULL COMMENT '消息内容',
  `message_type` TINYINT DEFAULT 1 COMMENT '消息类型(1-文字,2-图片,3-商品卡片)',
  `product_id` BIGINT COMMENT '关联商品ID',
  `is_read` TINYINT DEFAULT 0 COMMENT '是否已读(0-未读,1-已读)',
  `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  INDEX idx_from_user (`from_user_id`),
  INDEX idx_to_user (`to_user_id`),
  INDEX idx_create_time (`create_time`),
  FOREIGN KEY (`from_user_id`) REFERENCES `user`(`id`),
  FOREIGN KEY (`to_user_id`) REFERENCES `user`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='聊天消息表';

-- 11. 通知表
CREATE TABLE `notification` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '通知ID',
  `user_id` BIGINT NOT NULL COMMENT '用户ID',
  `title` VARCHAR(100) NOT NULL COMMENT '通知标题',
  `content` TEXT COMMENT '通知内容',
  `type` TINYINT NOT NULL COMMENT '通知类型(1-订单,2-评价,3-系统)',
  `related_id` BIGINT COMMENT '关联ID(订单ID/评价ID等)',
  `is_read` TINYINT DEFAULT 0 COMMENT '是否已读(0-未读,1-已读)',
  `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  INDEX idx_user_id (`user_id`),
  INDEX idx_is_read (`is_read`),
  FOREIGN KEY (`user_id`) REFERENCES `user`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='通知表';

-- 12. 管理员表
CREATE TABLE `admin_user` (
  `id` BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '管理员ID',
  `username` VARCHAR(50) NOT NULL UNIQUE COMMENT '用户名',
  `password` VARCHAR(255) NOT NULL COMMENT '密码(BCrypt加密)',
  `nickname` VARCHAR(50) COMMENT '昵称',
  `role` VARCHAR(20) DEFAULT 'admin' COMMENT '角色',
  `status` TINYINT DEFAULT 1 COMMENT '状态(0-禁用,1-启用)',
  `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='管理员表';

-- 插入初始数据

-- 插入一级分类
INSERT INTO `category` (`id`, `parent_id`, `name`, `icon`, `sort_order`) VALUES
(1, 0, '数码产品', 'icon-digital', 1),
(2, 0, '服装鞋包', 'icon-clothes', 2),
(3, 0, '图书音像', 'icon-book', 3),
(4, 0, '家居用品', 'icon-home', 4),
(5, 0, '美妆个护', 'icon-beauty', 5),
(6, 0, '运动户外', 'icon-sport', 6),
(7, 0, '其他', 'icon-other', 7);

-- 插入二级分类
INSERT INTO `category` (`parent_id`, `name`, `sort_order`) VALUES
(1, '手机', 1),
(1, '电脑', 2),
(1, '相机', 3),
(1, '耳机', 4),
(2, '男装', 1),
(2, '女装', 2),
(2, '鞋子', 3),
(2, '包包', 4),
(3, '小说', 1),
(3, '教材', 2),
(3, 'CD/DVD', 3),
(4, '家具', 1),
(4, '厨具', 2),
(4, '装饰', 3),
(5, '护肤', 1),
(5, '彩妆', 2),
(6, '运动器材', 1),
(6, '户外装备', 2);

-- 插入默认管理员账号 (用户名: admin, 密码: admin123)
INSERT INTO `admin_user` (`username`, `password`, `nickname`) VALUES
('admin', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iAt6Z5EH', '系统管理员');


