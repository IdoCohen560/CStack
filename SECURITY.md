# Security

## The trust model, stated plainly

- **CStack installs third-party plugins and tools.** They're credited and linked in the README, but
  they are not audited by this project. Review `setup.sh` before running it (it's one file), and
  review anything it installs to your own comfort level.
- **No secrets are stored by CStack.** Authentication is delegated: `gh auth login` and
  `codex login` use each tool's own credential store. CStack never asks for, writes, or transmits a
  key. The reviewer (Codex) runs on your existing ChatGPT auth.
- **The hooks run locally and read local state only.** They never phone home. GitNexus indexes your
  code locally into `.gitnexus/` and does not upload it.
- **Hooks fail open by design.** The review/graph/router hooks exit 0 (allow) on any error, so a bug
  in a hook can never lock you out of your session. The review "marker" is *advisory* — it enforces
  the workflow, it is not a security boundary against a hostile local process.

## What runs, what leaves your machine

| Action | Where it runs | Leaves your machine? |
|---|---|---|
| Cross-model review (Codex) | OpenAI, via your ChatGPT auth | the diff/prompt you send to Codex |
| Code graph (GitNexus) | local, offline | no |
| Hooks (review/graph/router) | local | no |
| Skills / doctrine | local, in-context | no |

`claude-video-vision` is the exception: if you enable it, it can send frames/audio to whatever vision
API you configure. It does nothing until you set that up.

## Reporting a vulnerability

Open a private security advisory on the repo, or email the maintainer. Please don't file public
issues for anything exploitable until it's addressed.
