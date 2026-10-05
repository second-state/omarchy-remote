# 经验教训

## 2026-10-02：`set -x` 把 Pangolin API key 打进了会话
- **经过**：调试 AI Gateway 时，在测试脚本里开了 `set -x`。`pg_api` 用 `printf 'header = "Authorization: Bearer %s"' "$(<key)"` 拼请求头，xtrace 把展开后的 key 原样打印了出来，key 只能作废重建。
- **规则**：
  1. 只要脚本会碰密钥（`pg_api`、`pangolin.key`、生成的密码或令牌），就绝不开 `set -x` 或 `bash -x`。要调试，就打印经过脱敏的响应。
  2. 处理密钥的函数开头要写 `local -; set +x`，这样调用方即使开了 xtrace 也追踪不到它。`pg_api` 已经这样改了。
  3. 遇到新接口，先拿假 key 或离线样例把流程跑通，再接真 key。

## 2026-10-05：在本机测试命令里用 `$args` 传多个参数，结果被 zsh 坑了两次
- **经过**：Bash 工具实际跑在 zsh 里，而 zsh 默认不会对 `$args` 做单词拆分。`expose $args` 收到的是一整个字符串，`curl $R` 也一样，于是测试结论是错的，还以为代码有 bug。
- **规则**：在本机写带循环或变量参数的测试，一律包进 `bash -c '…'` 或 `bash <<'EOF'` 里跑；也可以用数组。测试结果跟预期对不上时，先排除测试脚本本身的问题，再怀疑被测代码。
