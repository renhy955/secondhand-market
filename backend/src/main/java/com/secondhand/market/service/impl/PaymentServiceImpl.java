package com.secondhand.market.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.secondhand.market.common.BusinessException;
import com.secondhand.market.constants.OrderStatus;
import com.secondhand.market.entity.Order;
import com.secondhand.market.entity.Payment;
import com.secondhand.market.mapper.OrderMapper;
import com.secondhand.market.mapper.PaymentMapper;
import com.secondhand.market.service.PaymentService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentServiceImpl implements PaymentService {

    private final PaymentMapper paymentMapper;
    private final OrderMapper orderMapper;

    /**
     * 支付状态：待支付
     */
    private static final int PAYMENT_STATUS_PENDING = 0;
    /**
     * 支付状态：已支付
     */
    private static final int PAYMENT_STATUS_PAID = 1;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public String createPayment(Long orderId, Long userId) {
        Order order = orderMapper.selectById(orderId);
        if (order == null) {
            throw new BusinessException(404, "订单不存在");
        }

        if (!order.getBuyerId().equals(userId)) {
            throw new BusinessException(403, "无权操作此订单");
        }

        if (order.getStatus() != OrderStatus.PENDING_PAYMENT) {
            throw new BusinessException(400, "订单状态不正确或已支付");
        }

        // 检查是否已有待支付的支付记录，防止重复创建
        LambdaQueryWrapper<Payment> existWrapper = new LambdaQueryWrapper<>();
        existWrapper.eq(Payment::getOrderId, orderId)
                     .eq(Payment::getStatus, PAYMENT_STATUS_PENDING);
        Payment existPayment = paymentMapper.selectOne(existWrapper);
        if (existPayment != null) {
            log.info("订单[{}]已存在待支付记录，返回已有支付单号: {}", orderId, existPayment.getPaymentNo());
            return existPayment.getPaymentNo();
        }

        // 创建支付记录
        Payment payment = new Payment();
        payment.setPaymentNo("PAY" + UUID.randomUUID().toString().replace("-", "").substring(0, 16).toUpperCase());
        payment.setOrderId(orderId);
        payment.setUserId(userId);
        payment.setAmount(order.getTotalAmount());
        payment.setStatus(PAYMENT_STATUS_PENDING);
        payment.setPaymentMethod(1);
        paymentMapper.insert(payment);

        log.info("支付记录创建成功: paymentNo={}, orderId={}, amount={}", payment.getPaymentNo(), orderId, order.getTotalAmount());
        return payment.getPaymentNo();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void simulatePayment(String paymentNo, Long userId) {
        Payment payment = paymentMapper.selectOne(new LambdaQueryWrapper<Payment>()
                .eq(Payment::getPaymentNo, paymentNo));

        if (payment == null) {
            throw new BusinessException(404, "支付记录不存在");
        }

        // 验证支付人是订单买家
        if (!payment.getUserId().equals(userId)) {
            throw new BusinessException(403, "无权操作此支付");
        }

        if (payment.getStatus() != PAYMENT_STATUS_PENDING) {
            throw new BusinessException(400, "支付状态不正确或已支付");
        }

        // 验证支付金额与订单金额一致
        Order order = orderMapper.selectById(payment.getOrderId());
        if (order == null) {
            throw new BusinessException(404, "订单不存在");
        }
        if (payment.getAmount().compareTo(order.getTotalAmount()) != 0) {
            log.error("支付金额不匹配: paymentNo={}, paymentAmount={}, orderAmount={}",
                    paymentNo, payment.getAmount(), order.getTotalAmount());
            throw new BusinessException(400, "支付金额与订单金额不一致");
        }

        // 模拟支付成功
        String transactionId = "TXN" + UUID.randomUUID().toString().replace("-", "");
        log.info("模拟支付开始: paymentNo={}, transactionId={}", paymentNo, transactionId);
        paymentCallback(paymentNo, transactionId);
        log.info("模拟支付成功: paymentNo={}", paymentNo);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void paymentCallback(String paymentNo, String transactionId) {
        // 原子更新支付状态，防止并发重复支付
        LambdaUpdateWrapper<Payment> updateWrapper = new LambdaUpdateWrapper<>();
        updateWrapper.eq(Payment::getPaymentNo, paymentNo)
                .eq(Payment::getStatus, PAYMENT_STATUS_PENDING)
                .set(Payment::getStatus, PAYMENT_STATUS_PAID)
                .set(Payment::getTransactionId, transactionId);
        int rows = paymentMapper.update(null, updateWrapper);
        if (rows == 0) {
            log.warn("支付回调处理失败，可能已被处理或状态不匹配: paymentNo={}", paymentNo);
            return;
        }

        log.info("支付状态更新成功: paymentNo={}, transactionId={}", paymentNo, transactionId);

        // 更新订单状态
        Payment payment = paymentMapper.selectOne(new LambdaQueryWrapper<Payment>()
                .eq(Payment::getPaymentNo, paymentNo));
        if (payment != null) {
            Order order = orderMapper.selectById(payment.getOrderId());
            if (order != null && order.getStatus() == OrderStatus.PENDING_PAYMENT) {
                order.setStatus(OrderStatus.PENDING_SHIPMENT);
                order.setPayTime(LocalDateTime.now());
                orderMapper.updateById(order);
                log.info("订单状态更新为待发货: orderId={}", order.getId());
            }
        }
    }
}