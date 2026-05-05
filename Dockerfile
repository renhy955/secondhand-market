# =============================================
# 二手交易平台多阶段构建Dockerfile
# 工作目录: /app
# 基础镜像: Ubuntu
# =============================================

# ------------------------------
# 阶段1: 构建后端 (Backend Build)
# 使用Maven构建Spring Boot项目
# ------------------------------
FROM maven:3.8.6-openjdk-11 AS backend-build

WORKDIR /app

COPY backend/pom.xml ./backend/pom.xml
RUN cd /app/backend && mvn dependency:go-offline -B

COPY backend/src ./backend/src
RUN cd /app/backend && mvn clean package -DskipTests

# ------------------------------
# 阶段2: 构建前端 (Frontend Build)
# 使用Node.js构建Vue项目
# ------------------------------
FROM node:20-alpine AS frontend-build

WORKDIR /app/frontend

COPY frontend/package*.json ./
RUN npm install

COPY frontend/ ./
RUN npm run build

# ------------------------------
# 阶段3: 最终运行环境 (Runtime)
# 基于Ubuntu，包含所有运行时服务
# ------------------------------
FROM ubuntu:22.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin:/app

WORKDIR /app

# ------------------------------
# 安装系统依赖和软件包
# ------------------------------
RUN sed -i 's/ports.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && apt-get install -y \
    openjdk-11-jre-headless \
    curl \
    nginx \
    supervisor \
    default-mysql-server \
    redis-server \
    wget \
    net-tools \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default

# ------------------------------
# 从构建阶段复制产物
# ------------------------------
COPY --from=backend-build /app/backend/target/*.jar /app/backend.jar
COPY --from=frontend-build /app/frontend/dist /var/www/html
COPY database/init.sql /app/init.sql
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

# ------------------------------
# 创建必要的目录和权限设置
# ------------------------------
RUN mkdir -p /app/uploads \
    && mkdir -p /var/run/mysqld \
    && mkdir -p /var/log/supervisor \
    && chown -R www-data:www-data /var/www/html \
    && chown -R www-data:www-data /app/uploads \
    && chmod 777 /var/run/mysqld \
    && chmod 777 /run/mysqld 2>/dev/null || true

# ------------------------------
# 配置Supervisor
# ------------------------------
RUN echo "[supervisord]" > /etc/supervisor/conf.d/supervisord.conf \
    && echo "nodaemon=true" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "user=root" >> /etc/supervisor/conf.d/supervisord.conf

# MySQL配置
RUN echo "[program:mysql]" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "command=/bin/bash /usr/local/bin/mysql-init.sh" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "autostart=true" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "autorestart=true" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "stdout_logfile=/var/log/supervisor/mysql.log" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "stderr_logfile=/var/log/supervisor/mysql.error.log" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "priority=200" >> /etc/supervisor/conf.d/supervisord.conf

# 修改MySQL配置文件，取消注释port=3306
RUN sed -i 's/^# port          = 3306/port          = 3306/' /etc/mysql/mysql.conf.d/mysqld.cnf

# 创建MySQL初始化脚本
RUN echo "#!/bin/bash" > /usr/local/bin/mysql-init.sh \
    && echo "if [ ! -f /var/lib/mysql/ibdata1 ]; then" >> /usr/local/bin/mysql-init.sh \
    && echo "    /usr/sbin/mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql" >> /usr/local/bin/mysql-init.sh \
    && echo "fi" >> /usr/local/bin/mysql-init.sh \
    && echo "/usr/sbin/mysqld --user=mysql --socket=/var/run/mysqld/mysqld.sock --bind-address=127.0.0.1 --port=3306 &" >> /usr/local/bin/mysql-init.sh \
    && echo "for i in {1..60}; do" >> /usr/local/bin/mysql-init.sh \
    && echo "    if mysqladmin ping -u root --socket=/var/run/mysqld/mysqld.sock 2>/dev/null | grep -q 'alive'; then" >> /usr/local/bin/mysql-init.sh \
    && echo "        break" >> /usr/local/bin/mysql-init.sh \
    && echo "    fi" >> /usr/local/bin/mysql-init.sh \
    && echo "    sleep 1" >> /usr/local/bin/mysql-init.sh \
    && echo "done" >> /usr/local/bin/mysql-init.sh \
    && echo "mysql -u root --socket=/var/run/mysqld/mysqld.sock -e \"ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY ''; FLUSH PRIVILEGES;\" || true" >> /usr/local/bin/mysql-init.sh \
    && echo "mysql -u root --socket=/var/run/mysqld/mysqld.sock -e \"CREATE DATABASE IF NOT EXISTS secondhand_market DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;\" || true" >> /usr/local/bin/mysql-init.sh \
    && echo "mysql -u root --socket=/var/run/mysqld/mysqld.sock secondhand_market < /app/init.sql || true" >> /usr/local/bin/mysql-init.sh \
    && echo "tail -f /dev/null" >> /usr/local/bin/mysql-init.sh \
    && chmod +x /usr/local/bin/mysql-init.sh

# Redis配置
RUN echo "[program:redis]" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "command=/usr/bin/redis-server --bind 127.0.0.1 --port 6379 --save '' --appendonly no" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "autostart=true" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "autorestart=true" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "stdout_logfile=/var/log/supervisor/redis.log" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "stderr_logfile=/var/log/supervisor/redis.error.log" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "priority=200" >> /etc/supervisor/conf.d/supervisord.conf

# Nginx配置
RUN echo "[program:nginx]" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "command=/usr/sbin/nginx -g 'daemon off;'" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "autostart=true" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "autorestart=true" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "stdout_logfile=/var/log/supervisor/nginx.log" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "stderr_logfile=/var/log/supervisor/nginx.error.log" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "priority=100" >> /etc/supervisor/conf.d/supervisord.conf

# Spring Boot后端配置
RUN echo "[program:backend]" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "command=java -jar /app/backend.jar --spring.datasource.url=jdbc:mysql://localhost:3306/secondhand_market?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true --spring.datasource.username=root --spring.datasource.password= --spring.redis.host=localhost --spring.redis.port=6379 --server.port=8080" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "autostart=true" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "autorestart=true" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "stdout_logfile=/var/log/supervisor/backend.log" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "stderr_logfile=/var/log/supervisor/backend.error.log" >> /etc/supervisor/conf.d/supervisord.conf \
    && echo "priority=100" >> /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80 3306 6379 8080

# 容器启动命令
CMD ["/bin/bash", "-c", "\
pkill -9 mysqld 2>/dev/null || true && \
mkdir -p /var/run/mysqld && chmod 777 /var/run/mysqld && \
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf"]
