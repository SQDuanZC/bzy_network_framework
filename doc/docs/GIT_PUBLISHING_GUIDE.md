# Git 发布指南

本指南将详细说明如何将 BZY 网络框架发布到 GitHub，让其他开发者可以通过 Git 依赖的方式使用。

## 📋 需要上传的文件清单

### 🔧 核心文件（必须）

```
bzy_network_framework/
├── pubspec.yaml                    # 包配置文件
├── lib/                            # 核心代码目录
│   ├── bzy_network_framework.dart  # 主导出文件
│   └── src/                        # 源代码目录
│       ├── config/                 # 配置相关
│       ├── core/                   # 核心功能
│       ├── frameworks/             # 框架层
│       ├── model/                  # 数据模型
│       ├── requests/               # 请求相关
│       └── utils/                  # 工具类
├── LICENSE                         # 许可证文件
├── README.md                       # 项目说明
└── CHANGELOG.md                    # 更新日志
```

### 📚 文档文件（推荐）

```
doc/
├── docs/
│   ├── QUICK_START_GUIDE.md        # 快速开始指南
│   ├── ADVANCED_FEATURES.md        # 高级功能文档
│   ├── API_REFERENCE.md            # API 参考文档
│   └── BEST_PRACTICES.md           # 最佳实践
└── CODE_QUALITY_OPTIMIZATION_REPORT.md
```

### 🧪 测试文件（推荐）

```
test/
├── bzy_network_framework_test.dart # 主测试文件
└── network_test_base.dart          # 测试基础设施
```

### 📝 示例文件（可选）

```
example/
├── demo_app.dart                   # 演示应用
├── network_demo.dart               # 网络请求示例
├── queue_monitor_example.dart      # 队列监控示例
└── usage_examples.dart             # 使用示例
```

### ⚙️ 配置文件（推荐）

```
├── .gitignore                      # Git 忽略文件
├── analysis_options.yaml           # 代码分析配置
└── README_EN.md                    # 英文说明文档
```

## 🚀 发布步骤

### 1. 准备 GitHub 仓库

```bash
# 1. 在 GitHub 上创建新仓库
# 仓库名: bzy_network_framework
# 描述: BZY 统一网络请求框架 - 高性能、易扩展的 Flutter 网络解决方案

# 2. 克隆仓库到本地
git clone https://github.com/SQDuanZC/bzy_network_framework.git
cd bzy_network_framework
```

### 2. 创建包目录结构

```bash
# 创建标准的 Flutter 包目录结构
mkdir -p packages/bzy_network_framework
cd packages/bzy_network_framework
```

### 3. 复制文件到正确位置

将以下文件从当前项目复制到 `packages/bzy_network_framework/` 目录：

```bash
# 核心文件
cp -r /path/to/current/project/lib/netWork/lib ./
cp /path/to/current/project/lib/netWork/pubspec.yaml ./
cp /path/to/current/project/lib/netWork/LICENSE ./
cp /path/to/current/project/lib/netWork/README.md ./
cp /path/to/current/project/lib/netWork/CHANGELOG.md ./

# 测试文件
cp -r /path/to/current/project/lib/netWork/test ./

# 文档文件
cp -r /path/to/current/project/lib/netWork/doc ./

# 示例文件（可选）
cp -r /path/to/current/project/lib/netWork/example ./

# 配置文件
cp /path/to/current/project/lib/netWork/.gitignore ./
```

### 4. 更新 pubspec.yaml

确保 `pubspec.yaml` 包含正确的信息：

```yaml
name: bzy_network_framework
description: BZY 统一网络请求框架 - 高性能、易扩展的 Flutter 网络解决方案
version: 1.0.0
homepage: https://github.com/SQDuanZC/bzy_network_framework
repository: https://github.com/SQDuanZC/bzy_network_framework
issue_tracker: https://github.com/SQDuanZC/bzy_network_framework/issues

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.0.0'

dependencies:
  flutter:
    sdk: flutter
  dio: ^5.3.2
  logging: ^1.2.0
  device_info_plus: ^9.1.0
  package_info_plus: ^4.2.0
  connectivity_plus: ^5.0.1
  shared_preferences: ^2.2.2
  json_annotation: ^4.8.1
  crypto: ^3.0.3
  archive: ^3.4.10

dev_dependencies:
  flutter_test:
    sdk: flutter
  json_serializable: ^6.7.1
  build_runner: ^2.4.7
  flutter_lints: ^3.0.0
  mockito: ^5.4.0
  test: ^1.24.0
```

### 5. 创建 .gitignore 文件

```gitignore
# Miscellaneous
*.class
*.log
*.pyc
*.swp
.DS_Store
.atom/
.buildlog/
.history
.svn/

# IntelliJ related
*.iml
*.ipr
*.iws
.idea/

# The .vscode folder contains launch configuration and tasks you configure in
# VS Code which you may wish to be included in version control, so this line
# is commented out by default.
#.vscode/

# Flutter/Dart/Pub related
**/doc/api/
**/ios/Flutter/.last_build_id
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
/build/

# Web related
lib/generated_plugin_registrant.dart

# Symbolication related
app.*.symbols

# Obfuscation related
app.*.map.json

# Android Studio will place build artifacts here
/android/app/debug
/android/app/profile
/android/app/release
```

### 6. 提交到 GitHub

```bash
# 添加所有文件
git add .

# 提交更改
git commit -m "feat: 初始发布 BZY 网络框架 v1.0.0

- 完整的网络请求框架
- 支持缓存、拦截器、监控
- 类型安全的 API 设计
- 完善的文档和示例"

# 推送到 GitHub
git push origin main

# 创建版本标签
git tag v1.0.0
git push origin v1.0.0
```

## 📦 使用方式

其他开发者可以通过以下方式使用你的框架：

### 方式 1: Git 依赖（推荐用于开发阶段）

```yaml
dependencies:
  bzy_network_framework:
    git:
      url: https://github.com/SQDuanZC/bzy_network_framework
      path: packages/bzy_network_framework
```

### 方式 2: Git 依赖 + 特定版本

```yaml
dependencies:
  bzy_network_framework:
    git:
      url: https://github.com/SQDuanZC/bzy_network_framework
      path: packages/bzy_network_framework
      ref: v1.0.0  # 指定版本标签
```

### 方式 3: Git 依赖 + 特定分支

```yaml
dependencies:
  bzy_network_framework:
    git:
      url: https://github.com/SQDuanZC/bzy_network_framework
      path: packages/bzy_network_framework
      ref: develop  # 指定分支
```

## 🔄 版本管理

### 语义化版本控制

遵循 [语义化版本控制](https://semver.org/lang/zh-CN/) 规范：

- **主版本号 (MAJOR)**: 不兼容的 API 修改
- **次版本号 (MINOR)**: 向下兼容的功能性新增
- **修订号 (PATCH)**: 向下兼容的问题修正

### 发布新版本

```bash
# 1. 更新版本号
# 编辑 pubspec.yaml 中的 version 字段

# 2. 更新 CHANGELOG.md
# 添加新版本的更新内容

# 3. 提交更改
git add .
git commit -m "chore: 发布 v1.1.0"

# 4. 创建标签
git tag v1.1.0
git push origin main
git push origin v1.1.0
```

## 📋 最佳实践

### 1. 目录结构规范

```
bzy_network_framework/
├── packages/
│   └── bzy_network_framework/     # 主包
│       ├── lib/
│       ├── test/
│       ├── example/
│       ├── doc/
│       ├── pubspec.yaml
│       ├── README.md
│       ├── CHANGELOG.md
│       └── LICENSE
├── tools/                         # 构建工具（可选）
├── scripts/                       # 脚本文件（可选）
├── .github/                       # GitHub 配置
│   ├── workflows/                 # CI/CD 配置
│   └── ISSUE_TEMPLATE/            # Issue 模板
├── README.md                      # 项目总体说明
└── LICENSE                        # 项目许可证
```

### 2. 文档完整性

确保包含以下文档：

- ✅ **README.md**: 项目介绍、快速开始、基本用法
- ✅ **CHANGELOG.md**: 版本更新记录
- ✅ **LICENSE**: 开源许可证
- ✅ **API 文档**: 详细的 API 说明
- ✅ **示例代码**: 完整的使用示例
- ✅ **贡献指南**: 如何参与项目开发

### 3. 代码质量保证

- ✅ **单元测试**: 覆盖率 > 80%
- ✅ **代码分析**: 通过 `flutter analyze`
- ✅ **格式化**: 使用 `dart format`
- ✅ **类型安全**: 避免使用 `dynamic`
- ✅ **文档注释**: 为公共 API 添加文档注释

### 4. CI/CD 配置

创建 `.github/workflows/ci.yml`：

```yaml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
        
    - name: Install dependencies
      run: |
        cd packages/bzy_network_framework
        flutter pub get
        
    - name: Run tests
      run: |
        cd packages/bzy_network_framework
        flutter test
        
    - name: Run analyzer
      run: |
        cd packages/bzy_network_framework
        flutter analyze
```

## 🎯 发布检查清单

发布前请确认以下项目：

### 📋 代码质量
- [ ] 所有测试通过 (`flutter test`)
- [ ] 代码分析无错误 (`flutter analyze`)
- [ ] 代码格式正确 (`dart format`)
- [ ] 无编译错误或警告

### 📚 文档完整性
- [ ] README.md 包含完整的使用说明
- [ ] CHANGELOG.md 记录了所有更改
- [ ] API 文档完整且准确
- [ ] 示例代码可以正常运行

### 🔧 配置正确性
- [ ] pubspec.yaml 版本号正确
- [ ] 依赖版本兼容性检查
- [ ] 许可证文件存在
- [ ] .gitignore 配置合理

### 🚀 发布流程
- [ ] 创建了正确的版本标签
- [ ] 推送到了正确的分支
- [ ] GitHub 仓库设置正确
- [ ] 测试了 Git 依赖安装

## 🔍 故障排除

### 常见问题

**Q: 其他人无法通过 Git 依赖安装包**

A: 检查以下项目：
1. GitHub 仓库是否为公开状态
2. `path` 参数是否指向正确的目录
3. `pubspec.yaml` 文件是否存在且格式正确
4. 依赖的包是否都能正常获取

**Q: 版本更新后其他人获取不到最新代码**

A: 建议使用版本标签：
```yaml
bzy_network_framework:
  git:
    url: https://github.com/SQDuanZC/bzy_network_framework
    path: packages/bzy_network_framework
    ref: v1.1.0  # 明确指定版本
```

**Q: 包依赖冲突**

A: 检查并更新依赖版本范围，确保与其他包兼容。

---

**维护者**: BZY 网络框架开发团队  
**最后更新**: 2025年1月  
**版本**: v1.0.0