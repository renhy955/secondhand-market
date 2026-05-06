<template>
  <div class="publish-product-page">
    <Header />

    <div class="publish-container">
      <el-card>
        <template #header>
          <h2>发布商品</h2>
        </template>

        <el-form
          ref="formRef"
          :model="form"
          :rules="rules"
          label-width="100px"
          class="publish-form"
        >
          <!-- 商品图片 -->
          <el-form-item label="商品图片" prop="images" required>
            <el-upload
              v-model:file-list="fileList"
              :action="uploadUrl"
              list-type="picture-card"
              :on-preview="handlePreview"
              :on-success="handleUploadSuccess"
              :on-remove="handleRemove"
              :before-upload="beforeUpload"
              :limit="9"
              :headers="uploadHeaders"
            >
              <el-icon><Plus /></el-icon>
            </el-upload>
            <div class="upload-tip">最多上传9张图片，建议尺寸800x800</div>
          </el-form-item>

          <!-- 商品标题 -->
          <el-form-item label="商品标题" prop="title">
            <el-input
              v-model="form.title"
              placeholder="请输入商品标题，不超过50字"
              maxlength="50"
              show-word-limit
            />
          </el-form-item>

          <!-- 商品分类 -->
          <el-form-item label="商品分类" prop="categoryId">
            <el-select v-model="form.categoryId" placeholder="请选择分类" style="width: 100%">
              <el-option
                v-for="category in categories"
                :key="category.id"
                :label="category.name"
                :value="category.id"
              />
            </el-select>
          </el-form-item>

          <!-- 商品价格 -->
          <el-form-item label="商品价格" prop="price">
            <el-input
              v-model="form.price"
              placeholder="请输入价格"
              @input="handlePriceInput"
            >
              <template #prepend>¥</template>
            </el-input>
          </el-form-item>

          <!-- 商品成色 -->
          <el-form-item label="商品成色" prop="condition">
            <el-radio-group v-model="form.condition">
              <el-radio label="全新">全新</el-radio>
              <el-radio label="99新">99新</el-radio>
              <el-radio label="95新">95新</el-radio>
              <el-radio label="9成新">9成新</el-radio>
              <el-radio label="8成新">8成新</el-radio>
              <el-radio label="7成新以下">7成新以下</el-radio>
            </el-radio-group>
          </el-form-item>

          <!-- 交易方式 -->
          <el-form-item label="交易方式" prop="tradeType">
            <el-checkbox-group v-model="form.tradeType">
              <el-checkbox label="同城面交">同城面交</el-checkbox>
              <el-checkbox label="快递邮寄">快递邮寄</el-checkbox>
            </el-checkbox-group>
          </el-form-item>

          <!-- 所在位置 -->
          <el-form-item label="所在位置" prop="location">
            <el-cascader
              v-model="form.location"
              :options="regionOptions"
              placeholder="请选择省市区"
              style="width: 100%"
            />
          </el-form-item>

          <!-- 详细描述 -->
          <el-form-item label="详细描述" prop="description">
            <el-input
              v-model="form.description"
              type="textarea"
              :rows="6"
              placeholder="请详细描述商品信息，如购买时间、使用情况、瑕疵说明等"
              maxlength="1000"
              show-word-limit
            />
          </el-form-item>

          <!-- 提交按钮 -->
          <el-form-item>
            <el-button type="primary" size="large" @click="handleSubmit" :loading="submitting">
              发布商品
            </el-button>
            <el-button size="large" @click="handleCancel">
              取消
            </el-button>
          </el-form-item>
        </el-form>
      </el-card>
    </div>

    <!-- 图片预览对话框 -->
    <el-dialog v-model="previewVisible" title="图片预览">
      <el-image :src="previewImage" fit="contain" style="width: 100%" />
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus } from '@element-plus/icons-vue'
import Header from '@/components/Header.vue'
import { publishProduct } from '@/api/product'
import { getCategoryList } from '@/api/category'

const router = useRouter()
const formRef = ref(null)
const submitting = ref(false)

// 表单数据
const form = reactive({
  title: '',
  categoryId: '',
  price: '',
  condition: '全新',
  tradeType: [],
  location: [],
  description: '',
  images: []
})

// 文件列表
const fileList = ref([])

// 分类列表
const categories = ref([])

// 图片预览
const previewVisible = ref(false)
const previewImage = ref('')

// 上传配置
const uploadUrl = '/api/file/upload'
const uploadHeaders = ref({
  Authorization: `Bearer ${localStorage.getItem('token') || ''}`
})

// 省市区数据
const regionOptions = ref([
  {
    value: '北京',
    label: '北京',
    children: [
      { value: '北京市', label: '北京市', children: [
        { value: '东城区', label: '东城区' },
        { value: '西城区', label: '西城区' },
        { value: '朝阳区', label: '朝阳区' },
        { value: '海淀区', label: '海淀区' }
      ]}
    ]
  },
  {
    value: '上海',
    label: '上海',
    children: [
      { value: '上海市', label: '上海市', children: [
        { value: '黄浦区', label: '黄浦区' },
        { value: '徐汇区', label: '徐汇区' },
        { value: '长宁区', label: '长宁区' },
        { value: '静安区', label: '静安区' }
      ]}
    ]
  },
  {
    value: '广东',
    label: '广东',
    children: [
      { value: '广州市', label: '广州市', children: [
        { value: '天河区', label: '天河区' },
        { value: '越秀区', label: '越秀区' },
        { value: '海珠区', label: '海珠区' }
      ]},
      { value: '深圳市', label: '深圳市', children: [
        { value: '福田区', label: '福田区' },
        { value: '南山区', label: '南山区' },
        { value: '宝安区', label: '宝安区' }
      ]}
    ]
  }
])

// 表单验证规则
const rules = {
  title: [
    { required: true, message: '请输入商品标题', trigger: 'blur' },
    { min: 5, max: 50, message: '标题长度在5-50个字符', trigger: 'blur' }
  ],
  categoryId: [
    { required: true, message: '请选择商品分类', trigger: 'change' }
  ],
  price: [
    { required: true, message: '请输入商品价格', trigger: 'blur' },
    {
      validator: (rule, value, callback) => {
        if (value <= 0) {
          callback(new Error('价格必须大于0'))
        } else {
          callback()
        }
      },
      trigger: 'blur'
    }
  ],
  condition: [
    { required: true, message: '请选择商品成色', trigger: 'change' }
  ],
  tradeType: [
    { type: 'array', required: true, message: '请选择至少一种交易方式', trigger: 'change' }
  ],
  location: [
    { type: 'array', required: true, message: '请选择所在位置', trigger: 'change' }
  ],
  description: [
    { required: true, message: '请输入商品描述', trigger: 'blur' },
    { min: 10, message: '描述至少10个字符', trigger: 'blur' }
  ],
  images: [
    {
      type: 'array',
      required: true,
      validator: (rule, value, callback) => {
        if (form.images.length === 0) {
          callback(new Error('请至少上传1张商品图片'))
        } else {
          callback()
        }
      },
      trigger: 'change'
    }
  ]
}

// 价格输入处理
const handlePriceInput = (value) => {
  // 只允许数字和小数点
  form.price = value.replace(/[^\d.]/g, '')
  // 只保留第一个小数点
  const parts = form.price.split('.')
  if (parts.length > 2) {
    form.price = parts[0] + '.' + parts.slice(1).join('')
  }
  // 小数点后最多两位
  if (parts.length === 2 && parts[1].length > 2) {
    form.price = parts[0] + '.' + parts[1].substring(0, 2)
  }
}

// 上传前验证
const beforeUpload = (file) => {
  const token = localStorage.getItem('token')
  if (!token) {
    ElMessage.error('请先登录')
    return false
  }
  uploadHeaders.value.Authorization = `Bearer ${token}`

  const isImage = file.type.startsWith('image/')
  const isLt5M = file.size / 1024 / 1024 < 5

  if (!isImage) {
    ElMessage.error('只能上传图片文件')
    return false
  }
  if (!isLt5M) {
    ElMessage.error('图片大小不能超过5MB')
    return false
  }
  return true
}

// 上传成功
const handleUploadSuccess = (response, file) => {
  if (response.code === 200) {
    form.images.push(response.data.url)
    ElMessage.success('上传成功')
  } else {
    ElMessage.error(response.message || '上传失败')
    // 移除失败的文件
    const index = fileList.value.findIndex(item => item.uid === file.uid)
    if (index > -1) {
      fileList.value.splice(index, 1)
    }
  }
}

// 移除图片
const handleRemove = (file) => {
  const index = form.images.findIndex(url => url === file.response?.data?.url)
  if (index > -1) {
    form.images.splice(index, 1)
  }
}

// 预览图片
const handlePreview = (file) => {
  previewImage.value = file.url || file.response?.data?.url
  previewVisible.value = true
}

// 加载分类列表
const loadCategories = async () => {
  try {
    const res = await getCategoryList()
    categories.value = res.data || []
  } catch (error) {
    ElMessage.error('加载分类失败')
  }
}

// 提交表单
const handleSubmit = async () => {
  try {
    await formRef.value.validate()

    if (form.images.length === 0) {
      ElMessage.warning('请至少上传1张商品图片')
      return
    }

    submitting.value = true

    const submitData = {
      title: form.title,
      categoryId: form.categoryId,
      price: form.price,
      description: form.description,
      images: form.images,
      conditionLevel: form.condition,
      tradeType: form.tradeType.join(','),
      province: form.location[0] || '',
      city: form.location[1] || '',
      district: form.location[2] || ''
    }

    const res = await publishProduct(submitData)

    if (res.code === 200) {
      ElMessage.success('发布成功')
      router.push(`/product/${res.data.id}`)
    } else {
      ElMessage.error(res.message || '发布失败')
    }
  } catch (error) {
    console.error('发布失败', error)
  } finally {
    submitting.value = false
  }
}

// 取消发布
const handleCancel = () => {
  ElMessageBox.confirm('确定要取消发布吗？', '提示', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning'
  }).then(() => {
    router.back()
  }).catch(() => {})
}

onMounted(() => {
  loadCategories()
})
</script>

<style scoped>
.publish-product-page {
  min-height: 100vh;
  background: #f5f5f5;
}

.publish-container {
  max-width: 800px;
  margin: 20px auto;
  padding: 0 20px;
}

.publish-form {
  padding: 20px 0;
}

.upload-tip {
  font-size: 12px;
  color: #999;
  margin-top: 5px;
}

:deep(.el-upload--picture-card) {
  width: 100px;
  height: 100px;
}

:deep(.el-upload-list--picture-card .el-upload-list__item) {
  width: 100px;
  height: 100px;
}

@media (max-width: 768px) {
  .publish-container {
    padding: 0 10px;
  }

  :deep(.el-form-item__label) {
    width: 80px !important;
  }
}
</style>
