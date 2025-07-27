# BZY 网络框架发布指南

本指南详细说明如何将 BZY 网络框架发布到 pub.dev 以及如何进行版本管理。

## 📋 发布前检查清单

### 1. 代码质量检查

- [ ] 运行 `dart analyze` 确保无错误
- [ ] 运行 `dart test` 确保所有测试通过
- [ ] 检查代码覆盖率 (建议 > 80%)
- [ ] 确保遵循 Dart 代码规范

```bash
# 代码分析
dart analyze

# 运行测试
dart test

# 格式化代码
dart format .
```

### 2. 文档完整性检查

- [ ] README.md 包含完整的使用说明
- [ ] CHANGELOG.md 记录了所有版本变更
- [ ] API 文档完整且准确
- [ ] 示例代码可以正常运行

### 3. 包配置检查

- [ ] pubspec.yaml 配置正确
- [ ] 版本号遵循语义化版本规范
- [ ] 依赖版本约束合理
- [ ] 包含必要的元数据

## 🚀 发布步骤

### 步骤 1: 准备发布环境

```bash
# 确保 Flutter 和 Dart 版本最新
flutter upgrade
dart --version

# 安装 pub 发布工具
dart pub global activate pana
```

### 步骤 2: 验证包质量

```bash
# 运行包分析
dart pub publish --dry-run

# 使用 pana 分析包质量
pana .
```

### 步骤 3: 更新版本信息

1. **更新 pubspec.yaml 中的版本号**
```yaml
name: bzy_network_framework
version: 1.0.0  # 更新版本号
```

2. **更新 CHANGELOG.md**
```markdown
## [1.0.0] - 2024-12-19

### Added
- 新功能描述

### Changed
- 变更描述

### Fixed
- 修复描述
```

3. **更新 README.md 中的版本引用**
```yaml
dependencies:
  bzy_network_framework: ^1.0.0  # 更新版本号
```

### 步骤 4: 发布到 pub.dev

```bash
# 登录 pub.dev (首次发布需要)
dart pub login

# 发布包
dart pub publish
```

## 📦 包结构要求

发布的包应包含以下文件结构：

```
bzy_network_framework/
├── lib/
│   ├── bzy_network_framework.dart  # 主入口文件
│   ├── src/                        # 源代码目录
│   └── ...
├── test/                           # 测试文件
├── example/                        # 示例代码
├── docs/                           # 文档
├── pubspec.yaml                    # 包配置
├── README.md                       # 说明文档
├── CHANGELOG.md                    # 变更日志
└── LICENSE                         # 许可证
```

## 🏷️ 版本管理策略

### 语义化版本规范

版本号格式：`MAJOR.MINOR.PATCH`

- **MAJOR**: 不兼容的 API 修改
- **MINOR**: 向下兼容的功能性新增
- **PATCH**: 向下兼容的问题修正

### 版本发布策略

#### 主版本 (Major)
- 重大架构变更
- 不兼容的 API 修改
- 移除废弃功能
- 发布周期：6-12 个月

#### 次版本 (Minor)
- 新功能添加
- 向下兼容的 API 增强
- 性能优化
- 发布周期：1-3 个月

#### 修订版本 (Patch)
- Bug 修复
- 安全更新
- 文档更新
- 发布周期：根据需要

### 预发布版本

```yaml
# Alpha 版本 (内部测试)
version: 1.1.0-alpha.1

# Beta 版本 (公开测试)
version: 1.1.0-beta.1

# Release Candidate (发布候选)
version: 1.1.0-rc.1
```

## 🔧 自动化发布

### 使用 GitHub Actions

创建 `.github/workflows/publish.yml`：

```yaml
name: Publish to pub.dev

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable
          
      - name: Install dependencies
        run: dart pub get
        
      - name: Run tests
        run: dart test
        
      - name: Publish
        uses: k-paxian/dart-package-publisher@v1.5.1
        with:
          credentialJson: ${{ secrets.PUB_CREDENTIALS }}
          flutter: true
          skipTests: false
```

### 发布脚本

使用提供的发布脚本：

```bash
# 运行发布准备脚本
dart run scripts/prepare_release.dart

# 检查生成的发布包
ls -la release/
```

## 📊 发布后维护

### 1. 监控包使用情况

- 查看 pub.dev 上的下载统计
- 监控 GitHub Issues 和 Pull Requests
- 收集用户反馈

### 2. 持续改进

- 定期更新依赖
- 修复发现的问题
- 添加新功能
- 优化性能

### 3. 社区支持

- 及时回复 Issues
- 审查 Pull Requests
- 更新文档
- 发布更新公告

## 🚨 常见问题

### 发布失败

**问题**: `dart pub publish` 失败

**解决方案**:
1. 检查网络连接
2. 确认已登录 pub.dev
3. 检查包名是否已被占用
4. 验证 pubspec.yaml 格式

### 版本冲突

**问题**: 版本号已存在

**解决方案**:
1. 更新版本号
2. 确保版本号大于当前发布版本
3. 检查 CHANGELOG.md 是否同步更新

### 依赖问题

**问题**: 依赖版本约束过严

**解决方案**:
1. 使用宽松的版本约束
2. 测试与不同版本的兼容性
3. 更新依赖到最新稳定版本

## 📞 支持与反馈

如果在发布过程中遇到问题，请通过以下方式获取帮助：

- **GitHub Issues**: https://github.com/SQDuanZC/bzy_network_framework/issues
- **邮箱**: bzysq521@163.com
- **文档**: https://pub.dev/packages/bzy_network_framework

---

**BZY 团队** - 致力于为 Flutter 社区提供优质的网络解决方案