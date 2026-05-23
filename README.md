# SBC Depot

A community-driven, terminal-based app store for Raspberry Pi.
Zero servers. GitHub-backed. Secure by design.

## Install

```bash
git clone https://github.com/kannanokannan/sbcdepot
cd sbcdepot
chmod +x sbcdepot.sh
./sbcdepot.sh
```

## Add an App

1. Fork this repo
2. Copy `templates/app_template.json` into `apps/your-app-name.json`
3. Fill in the fields
4. Open a Pull Request

The CI pipeline will validate your submission automatically.
Only `apt` and `git_clone` methods are accepted.

## Security

See `sbcdepot.sh` for the full threat model.
No `eval`. No arbitrary remote code execution. Ever.
