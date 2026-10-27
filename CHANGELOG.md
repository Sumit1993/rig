# Changelog

## [0.18.0](https://github.com/Sumit1993/rig/compare/rig-v0.17.2...rig-v0.18.0) (2026-10-27)


### Features

* **farm-out:** lanes set up, stop and tear down cleanly on agy 1.4 and native Windows ([1ce7fe2](https://github.com/Sumit1993/rig/commit/1ce7fe215949b93766cff3f29cb90efa634c058b))
* **hooks:** add safe-stash PreToolUse hook for git stash commands ([f351ec1](https://github.com/Sumit1993/rig/commit/f351ec176ebdc2c7716944742e1d687b29f976f8))
* **hooks:** no-thread-resolve, the session never resolves a reviewer's thread ([f2238a4](https://github.com/Sumit1993/rig/commit/f2238a46422f4835c6a6c88c2ca70020651d89f2))
* **hooks:** safe-stash and no-thread-resolve enforce two doctrine lines ([ffc5e14](https://github.com/Sumit1993/rig/commit/ffc5e14cd5e312da015319e95737fd687900e7e3))
* **review-lanes:** the routine skips a coderabbit_skip PR, and a bare resolve passes summon-gate ([509ec83](https://github.com/Sumit1993/rig/commit/509ec834463c49f19cacf17763f950087f61a3bd)), closes [#189](https://github.com/Sumit1993/rig/issues/189)
* **skills:** behavior v0.2, check existing coverage first and layer forms ([a2cca21](https://github.com/Sumit1993/rig/commit/a2cca212fc09947190d69b3dbe7f777b64bac758))
* **skills:** behavior, from a wish to a landed, tested behavior ([a1860dd](https://github.com/Sumit1993/rig/commit/a1860ddaff6c33452ab86e1a00039e57f9029fea))


### Bug Fixes

* **hooks:** gh_scan sees a gh call after do, then, else, elif, ! and a brace ([64f87b1](https://github.com/Sumit1993/rig/commit/64f87b1ab0b737ef50ee236aa10bfe66572411b7))
* **hooks:** merge-gate checks every merge in a command; a brace counts only as a brace group ([47c7549](https://github.com/Sumit1993/rig/commit/47c75499e6285813583575e21b115292fc48f064))
* **hooks:** merge-gate checks every merge, including one after do, then, else, ! or a brace ([9acae6c](https://github.com/Sumit1993/rig/commit/9acae6c26c955c5fc90f5115cdb0e02f40374431))
* **hooks:** merge-gate reads every merge call in one pass and takes each token from its own call ([a4c271c](https://github.com/Sumit1993/rig/commit/a4c271c069d883afcd55ca54cbda26c6a5169e7b))
* **hooks:** merge-gate sees a merge after if, while or until, and blocks when perl is missing ([824a7cc](https://github.com/Sumit1993/rig/commit/824a7cca5b0bedc6eb0107cc5ae05ed3f7faedd6))
* **hooks:** no-thread-resolve and safe-stash fail closed without perl; tests isolate PATH and HOME ([ddc6940](https://github.com/Sumit1993/rig/commit/ddc6940a8f26f376adf50da7a5972436b933718e))
* **hooks:** no-thread-resolve fails closed on any gh api graphql call naming the mutation; skill corrects the Codex apply_patch matcher ([57027cb](https://github.com/Sumit1993/rig/commit/57027cb65df988d49ba7a4790e2638b25bd1f1eb))
* **hooks:** no-thread-resolve reads the gh api graphql call, not prose that names it ([e21e0a3](https://github.com/Sumit1993/rig/commit/e21e0a3ab73fb82e101e36ecc5f52364ab344e80))
* **hooks:** safe-stash catches git -C &lt;path&gt; stash and git -c k=v stash ([4217c21](https://github.com/Sumit1993/rig/commit/4217c21ee0e55cfbc62add4ca8b1a940797a9977))
* **hooks:** safe-stash reads git global options; no-thread-resolve catches heredoc, variable and env-wrapped mutations ([7550ad8](https://github.com/Sumit1993/rig/commit/7550ad83ba5a115bfe4061228173274793b3562e))
* **install:** quote agy's statusline script path on Windows ([7ed0e4d](https://github.com/Sumit1993/rig/commit/7ed0e4d6d3bd0b6682f4e250cfa8fe0e444785b6))
* **install:** run agy's statusline through bash on Windows ([2742160](https://github.com/Sumit1993/rig/commit/2742160b15301cc9bdae4ce6c1082c28367a893b))
* **install:** run agy's statusline through bash on Windows ([e5f0545](https://github.com/Sumit1993/rig/commit/e5f05456ef76a831d4c9f1437078812737192114))
* **skills:** behavior, a setting that covers part of a behavior still lands ([bf8d051](https://github.com/Sumit1993/rig/commit/bf8d051b6edbb7ef1d3444fbd6e83cfdc338dad5))
* **windows:** adversary and codex-desktop skills run on native Windows ([5ae3b86](https://github.com/Sumit1993/rig/commit/5ae3b861e25daa2c9cfe0f0f9149d83606837fdf))
* **windows:** adversary and codex-desktop skills run on native Windows ([acf04ec](https://github.com/Sumit1993/rig/commit/acf04ec4cb4bbb83f9c86767ee998ad91a808be0))


### Documentation

* **agents:** pick the model tier by the task's shape ([17f7736](https://github.com/Sumit1993/rig/commit/17f7736d0a39055914393bf1e1d0f8a8cb520c01))
* **agents:** pick the model tier by the task's shape ([2a05e53](https://github.com/Sumit1993/rig/commit/2a05e53a0a966c79ffe22ed7b3112c9181353c08))
* **codex-desktop:** the keep-it-in-WSL rule applies to WSL machines only ([23ebd2d](https://github.com/Sumit1993/rig/commit/23ebd2d7f5d722054167b68d4431dac759953395))
* **farm-out:** monitor and text-return lines are for Claude subagents; agy adds worktrees with git; autopilot points at farm-out ([dc5088c](https://github.com/Sumit1993/rig/commit/dc5088ca63cbd7c75b7bf224aeba05e45b3fba46))
* name the new blocking hooks in the gates list; thread resolves go through the UI ([5351210](https://github.com/Sumit1993/rig/commit/5351210a44194efce3c504e5776a54ceb31495b0))
* **readme:** behavior skill, safe-stash and no-thread-resolve; list the skill for Claude and Codex ([30b11dd](https://github.com/Sumit1993/rig/commit/30b11dd0fd7dd8d08c5146c98afb51f8d25940f3))
* **review-lanes:** Codex has a lane skill, and the skip label and verified-but-open resolve are written down ([3a3350c](https://github.com/Sumit1993/rig/commit/3a3350c14bf488ffac5b689c7e6aaaee324430a9)), closes [#189](https://github.com/Sumit1993/rig/issues/189)
* **review-lanes:** Codex threads are the operator's to resolve under the merge rule; compass cites claude-review-lane §6 ([42bfb46](https://github.com/Sumit1993/rig/commit/42bfb46c869d87e5f7099cdef5e66255777b976d))


### Code Refactoring

* drop the behavior skill; safe-stash and no-thread-resolve stand alone ([014c2d5](https://github.com/Sumit1993/rig/commit/014c2d57938aa1ba647d42af1e53c36b3530c7fa))


### Tests

* **adversary:** compare cwd paths resolved, so 8.3 short names match ([bfdce08](https://github.com/Sumit1993/rig/commit/bfdce08dd083bb2f4ee214f10aff30decfdf1357))
* **hooks:** merge-gate drops the contrived bypass cases; gh_scan drops unused count mode ([21644ae](https://github.com/Sumit1993/rig/commit/21644ae7eece5e4b7767401df06e509ed83409ac))


### Continuous Integration

* hooks and skill-script tests run on windows-latest; builder test reads agy's new validate output ([903b8a7](https://github.com/Sumit1993/rig/commit/903b8a7b48b749f2812fec702a265ad972fb5e66))

## [0.17.2](https://github.com/Sumit1993/rig/compare/rig-v0.17.1...rig-v0.17.2) (2026-10-19)


### Bug Fixes

* **coderabbit-routine:** a Review finished reply to a summon after head counts as reviewing head ([de2a2e0](https://github.com/Sumit1993/rig/commit/de2a2e0f050dec3b639fbcdeb7c6104ae498e0ca))
* **coderabbit-routine:** a Review finished reply to a summon after head counts as reviewing head ([4b5c6a3](https://github.com/Sumit1993/rig/commit/4b5c6a3a3567b39dfe7b7b4914e440b592ce7e03))
* **coderabbit-routine:** pair each summon with its own invocation reply before counting Review finished on head ([315e351](https://github.com/Sumit1993/rig/commit/315e3516c16180e8f8f3b5a86be426cffc5ea929))
* **windows:** path checks hold without cygpath, and UNC body files resolve ([752a6e6](https://github.com/Sumit1993/rig/commit/752a6e620c7062b1b9b8697c82a92273d5d11af4))
* **windows:** rig installs and its hooks run on native Windows under Git Bash ([b9d8ed6](https://github.com/Sumit1993/rig/commit/b9d8ed6a881d8586b3f3609eebab19e8fd7e54f2))
* **windows:** rig installs and its hooks run on native Windows under Git Bash ([609e4ac](https://github.com/Sumit1993/rig/commit/609e4ac87f52d01516ee6c31bcf921c0586a80be))

## [0.17.1](https://github.com/Sumit1993/rig/compare/rig-v0.17.0...rig-v0.17.1) (2026-10-11)


### Bug Fixes

* **coderabbit-routine:** the digest sleeps out a slot that opens within 8 minutes, then reads again ([5fd4369](https://github.com/Sumit1993/rig/commit/5fd4369b21a0b28cb22e76fce2d0dfac508951fe))
* **coderabbit-routine:** the slot stamp counts from the post, and a run sleeps out a slot that opens within 8 minutes ([20ccbf1](https://github.com/Sumit1993/rig/commit/20ccbf13be840e7da1d3dcdf3e7d2fca7b1c0889))
* **coderabbit-routine:** the slot stamp counts from the post, and a run sleeps out a slot that opens within 8 minutes ([#191](https://github.com/Sumit1993/rig/issues/191)) ([20ccbf1](https://github.com/Sumit1993/rig/commit/20ccbf13be840e7da1d3dcdf3e7d2fca7b1c0889))
* **coderabbit-routine:** the slot stamp counts from the post, and act.py waits out a slot that opens within 5 minutes ([b9b3260](https://github.com/Sumit1993/rig/commit/b9b326060f0b2831d95b9c4cd02be97943aecfd8))
* **hooks:** every hook carries its script name, and install --check reads the highest plugin version ([506fb63](https://github.com/Sumit1993/rig/commit/506fb6305d7d46ebc68555dab05eccde3ab8b8dd))
* **hooks:** every hook carries its script name, and install --check reads the highest plugin version ([795e390](https://github.com/Sumit1993/rig/commit/795e390007928d092c688e7c1730055203e8a69e))
* **hooks:** every hook carries its script name, and install --check reads the highest plugin version ([#190](https://github.com/Sumit1993/rig/issues/190)) ([506fb63](https://github.com/Sumit1993/rig/commit/506fb6305d7d46ebc68555dab05eccde3ab8b8dd))


### Continuous Integration

* bump actions/setup-python from 6 to 7 ([cec958d](https://github.com/Sumit1993/rig/commit/cec958ded4136d5cd8700841d2a50854a3e1f65d))
* bump actions/setup-python from 6 to 7 ([#176](https://github.com/Sumit1993/rig/issues/176)) ([cec958d](https://github.com/Sumit1993/rig/commit/cec958ded4136d5cd8700841d2a50854a3e1f65d))


### Miscellaneous Chores

* **coderabbit-routine:** drop a stray test stub committed by mistake ([8524fde](https://github.com/Sumit1993/rig/commit/8524fdefc6eb9a051da701499c2df6c09306ebee))

## [0.17.0](https://github.com/Sumit1993/rig/compare/rig-v0.16.0...rig-v0.17.0) (2026-10-11)


### Features

* **coderabbit-routine:** the summon marker carries slot_opens_at, and the digest decides the budget slot ([1df26ad](https://github.com/Sumit1993/rig/commit/1df26ad9245f9bb7252ad1f7c7c7151e5818d17d))
* **coderabbit-routine:** the summon marker carries slot_opens_at, and the digest decides the budget slot ([87fd91e](https://github.com/Sumit1993/rig/commit/87fd91e8de2d0c1f28f63c2619582c2b2df6a4d5))
* **coderabbit-routine:** the summon marker carries slot_opens_at, and the digest decides the budget slot ([#182](https://github.com/Sumit1993/rig/issues/182)) ([1df26ad](https://github.com/Sumit1993/rig/commit/1df26ad9245f9bb7252ad1f7c7c7151e5818d17d))
* **codex-judge:** Codex usage limits are checked before a judgment and shown at session start ([d30e963](https://github.com/Sumit1993/rig/commit/d30e96380fce3ed4169a8351337a3dd561b750a4))
* seats instead of fixed models, and rig installs per harness ([c057429](https://github.com/Sumit1993/rig/commit/c05742946fde9ed84b15ee4dba73e277d42f664e))
* seats instead of fixed models, and rig installs per harness ([e631830](https://github.com/Sumit1993/rig/commit/e6318301f285e5423c81b6b9a61cbbbca18926d0))
* seats instead of fixed models, and rig installs per harness ([#183](https://github.com/Sumit1993/rig/issues/183)) ([c057429](https://github.com/Sumit1993/rig/commit/c05742946fde9ed84b15ee4dba73e277d42f664e))


### Bug Fixes

* **coderabbit-routine:** a closed PR's routine summon still holds the slot ([7b28b4e](https://github.com/Sumit1993/rig/commit/7b28b4e8a66fea3f0fe8c9eb973dc3d5a055acb1))
* **statusline:** the status line no longer blanks on renders whose trace row is unchanged ([#184](https://github.com/Sumit1993/rig/issues/184)) ([6394054](https://github.com/Sumit1993/rig/commit/6394054419340e3f700fdf69de30e5e5ce5237cb))


### Documentation

* stacked PRs wait for MERGED; agy lanes run one suite at a time and e2e Verify names every suite ([18a1e6f](https://github.com/Sumit1993/rig/commit/18a1e6f53789829a58cd1dd96ad34f3de6a941ed))

## [0.16.0](https://github.com/Sumit1993/rig/compare/rig-v0.15.0...rig-v0.16.0) (2026-10-10)


### Features

* **codex-desktop:** start Codex desktop threads with no click and queue work to them ([#179](https://github.com/Sumit1993/rig/issues/179)) ([23eb103](https://github.com/Sumit1993/rig/commit/23eb10362b95f5b76488ac0be78d9d14b62d730b))
* **codex-desktop:** threads can ask the dispatching Claude session; rig installs on the Windows side ([#180](https://github.com/Sumit1993/rig/issues/180)) ([8351bff](https://github.com/Sumit1993/rig/commit/8351bffe2da509db69f01866732928a45bb6070c))
* **r2-sync:** back up Codex and Windows-side transcripts; resumed sessions no longer fail the run ([#178](https://github.com/Sumit1993/rig/issues/178)) ([13a271e](https://github.com/Sumit1993/rig/commit/13a271ed1c55a9336eee5372f8cfeafc769433aa))

## [0.15.0](https://github.com/Sumit1993/rig/compare/rig-v0.14.0...rig-v0.15.0) (2026-10-08)


### Features

* **coderabbit-routine:** Slack summary reads as sections, one PR per line with its title ([258474f](https://github.com/Sumit1993/rig/commit/258474f5b1c6fc319f89b2ac22c1e91be7d44914))
* **coderabbit-routine:** Slack summary reads as sections, one PR per line with its title ([35bf007](https://github.com/Sumit1993/rig/commit/35bf007a25550a4673f1ab0968c599119712a2f3))
* **codex:** adversarial judge and Windows desktop handoff ([#175](https://github.com/Sumit1993/rig/issues/175)) ([d0d4218](https://github.com/Sumit1993/rig/commit/d0d4218947bfdafdf786ddfa99445d0bcc51c26f))
* **farm-out:** agy lanes run the agy way and cost no Claude tokens while they work ([#168](https://github.com/Sumit1993/rig/issues/168)) ([9968bd5](https://github.com/Sumit1993/rig/commit/9968bd5f2be5e68023b6b8207794d56949399524))


### Bug Fixes

* **coderabbit-routine:** docs-only PRs rank last instead of never, so prismalens.io gets reviewed ([#159](https://github.com/Sumit1993/rig/issues/159)) ([#173](https://github.com/Sumit1993/rig/issues/173)) ([3abcbb0](https://github.com/Sumit1993/rig/commit/3abcbb05f2a6d9aaef8e5288e6697cb8dbbdaadd))

## [0.14.0](https://github.com/Sumit1993/rig/compare/rig-v0.13.0...rig-v0.14.0) (2026-10-06)


### Features

* **coderabbit-routine:** every run posts its summary to Slack, not only failures ([585b399](https://github.com/Sumit1993/rig/commit/585b399d281c1696e5c01dbd3bdf8b070c510532))
* **coderabbit-routine:** every run posts its summary to Slack; one bad PR no longer drops its repo ([463585c](https://github.com/Sumit1993/rig/commit/463585c19a46477d77b081a68e2b2fa941bde58d))
* **coderabbit-routine:** every run posts its summary to Slack; one bad PR no longer drops its repo ([#166](https://github.com/Sumit1993/rig/issues/166)) ([463585c](https://github.com/Sumit1993/rig/commit/463585c19a46477d77b081a68e2b2fa941bde58d))
* **coderabbit-routine:** no 20-minute head-age wait; draft state is the hold ([e9a6424](https://github.com/Sumit1993/rig/commit/e9a642413d917cf5c87f7bba875b915923fedb41))
* **coderabbit-routine:** one bad PR no longer drops its repo; failures alert Slack ([9f8392c](https://github.com/Sumit1993/rig/commit/9f8392c95aae2927b20cbc997d3558299af5a9e9))


### Bug Fixes

* **coderabbit-routine:** a malformed PR or digest degrades to an error line; a failed Slack post still prints the summary ([3446a30](https://github.com/Sumit1993/rig/commit/3446a3029b1399d64e1b6bbff4899ec24d8a1065))
* **coderabbit-routine:** pagination keeps the repos/ path the cloud proxy accepts ([#162](https://github.com/Sumit1993/rig/issues/162)) ([fdfead8](https://github.com/Sumit1993/rig/commit/fdfead81f9e1eddd1c4da1368504b84ea64e7087))
* **farm-out:** agy lanes per item, foreground suites, timeout is not success; merge commits everywhere ([b5f98ef](https://github.com/Sumit1993/rig/commit/b5f98efd660f9c819bbe62d482677a4c2fd6788a))
* **hooks:** ANSI-C decoder keeps the backslash on escapes bash keeps; watchdog grep error is not success; cite agy and release-please claims ([4c8753d](https://github.com/Sumit1993/rig/commit/4c8753d7a3ed778571ef74e979b7f1776da8ec15))
* **hooks:** stamp gate reads $'...' bodies; pr-created stops flagging cited titles and stacked PRs ([2572c0f](https://github.com/Sumit1993/rig/commit/2572c0f8deb5cbc708b65ca30b366d6e68b31b44))
* **hooks:** stamp gate reads $'...' bodies; pr-created stops flagging cited titles and stacked PRs ([f617ff4](https://github.com/Sumit1993/rig/commit/f617ff41c1b0b491e1dfff5b57d82822fe14f833))
* **hooks:** stamp gate reads $'...' bodies; pr-created stops flagging cited titles and stacked PRs ([#165](https://github.com/Sumit1993/rig/issues/165)) ([2572c0f](https://github.com/Sumit1993/rig/commit/2572c0f8deb5cbc708b65ca30b366d6e68b31b44))
* **pr-babysit:** drop the date marker the doc lint rejects ([7f66e6d](https://github.com/Sumit1993/rig/commit/7f66e6d37ddf1685a54db4f4e9b42bb8b221ed37))
* **rig:** review debt is per repo, the watchdog signature is written down, no bare stash in a lane, summon gate keys on the handle ([#161](https://github.com/Sumit1993/rig/issues/161)) ([d460e3e](https://github.com/Sumit1993/rig/commit/d460e3e1bcadfbc2773e85235719bf86870db621)), closes [#160](https://github.com/Sumit1993/rig/issues/160)


### Documentation

* **pr-babysit:** a classic merge passes the PR title as its subject, so the merge commit is conventional too ([f99d5a7](https://github.com/Sumit1993/rig/commit/f99d5a7885a06bb4937693b5ad4d016692774d29))


### Miscellaneous Chores

* **rig:** drop the ai-context write nudge; SendMessage ban covers only agy lanes ([c154d7c](https://github.com/Sumit1993/rig/commit/c154d7c723590ab388c9a218a781977d4a267a18))

## [0.13.0](https://github.com/Sumit1993/rig/compare/rig-v0.12.0...rig-v0.13.0) (2026-09-30)


### Features

* **rig:** effort per agent, named section citations, and five doctrine gaps from the issue sweep ([#156](https://github.com/Sumit1993/rig/issues/156)) ([1fa8fe1](https://github.com/Sumit1993/rig/commit/1fa8fe10d2e9ffcd79c7db0f725d0cfdd7c1e84c))
* **rig:** load less, say it once: rightsized for Claude 5.5-generation models ([#158](https://github.com/Sumit1993/rig/issues/158)) ([fa08c98](https://github.com/Sumit1993/rig/commit/fa08c98574e42efa3b6f4c5f0de983455a43ccb7))


### Bug Fixes

* **coderabbit-routine:** the model skips re-reviews of fixes CodeRabbit already confirmed in-thread ([#154](https://github.com/Sumit1993/rig/issues/154)) ([7a14cf4](https://github.com/Sumit1993/rig/commit/7a14cf4441579605ee4ce12a3327c63570d16dea)), closes [#153](https://github.com/Sumit1993/rig/issues/153)

## [0.12.0](https://github.com/Sumit1993/rig/compare/rig-v0.11.0...rig-v0.12.0) (2026-09-25)


### Features

* reviews run async through the hourly queue; review debt first; agy takes side work and the organizer seat goes ([#152](https://github.com/Sumit1993/rig/issues/152)) ([8041a9e](https://github.com/Sumit1993/rig/commit/8041a9e993d53f335e1d00e8ab69d75cafdfeda2))


### Continuous Integration

* bump actions/checkout from 4 to 7 ([#148](https://github.com/Sumit1993/rig/issues/148)) ([c21fdf9](https://github.com/Sumit1993/rig/commit/c21fdf9986ba99443657364ce0d60044132d4be0))

## [0.11.0](https://github.com/Sumit1993/rig/compare/rig-v0.10.0...rig-v0.11.0) (2026-09-24)


### ⚠ BREAKING CHANGES

* **rig:** installs need the marketplace re-added as Sumit1993/rig and rig@rig enabled in place of rig@agent-rig.
* **rig:** the kit: skill prefix is now rig:, and kit@claude-kit is now rig@agent-rig.

### Features

* **rig:** DuckDB queries replace the miners; agy-quota live; Codex CLI as third harness ([#140](https://github.com/Sumit1993/rig/issues/140)) ([716a010](https://github.com/Sumit1993/rig/commit/716a0101aae51c229bba619e16c0c1ae4955a0e4))
* **rig:** rename claude-kit to agent-rig and the kit plugin to rig ([#138](https://github.com/Sumit1993/rig/issues/138)) ([cf7aabe](https://github.com/Sumit1993/rig/commit/cf7aabe71ad0e4c17f18d7848476bd578ff1bfa6))
* **rig:** the record split: issues hold decisions, ai-context holds the run; six hooks and record hygiene checks ([#142](https://github.com/Sumit1993/rig/issues/142)) ([6e8c483](https://github.com/Sumit1993/rig/commit/6e8c483b30b775a8c08a06a506795599dcc08a96))


### Bug Fixes

* **rig:** hook gates read the posted body; hooks.json keys; review-lane docs from gh-workflows [#173](https://github.com/Sumit1993/rig/issues/173) ([#137](https://github.com/Sumit1993/rig/issues/137)) ([f732ce9](https://github.com/Sumit1993/rig/commit/f732ce909de05180b602b651dde5c456acd95392)), closes [#136](https://github.com/Sumit1993/rig/issues/136)
* **rig:** pause marker survives replies; verdicts are prefixes; fable-planner reads the record first ([#144](https://github.com/Sumit1993/rig/issues/144)) ([fe212da](https://github.com/Sumit1993/rig/commit/fe212da17e94abeab90c87377babf02c58cdfa19))


### Documentation

* **claude-review-lane:** admission modes and the two admission labels (gh-workflows[#194](https://github.com/Sumit1993/rig/issues/194)) ([#147](https://github.com/Sumit1993/rig/issues/147)) ([125f64a](https://github.com/Sumit1993/rig/commit/125f64a0b6349baccc68b1cdef41c83d883a3e01))


### Continuous Integration

* add Dependabot for github-actions, with an auto-merge caller ([#146](https://github.com/Sumit1993/rig/issues/146)) ([67f7ae3](https://github.com/Sumit1993/rig/commit/67f7ae328090d0386b3a50b700a751fc0afd3ec9))

## [0.10.0](https://github.com/Sumit1993/claude-kit/compare/kit-v0.9.0...kit-v0.10.0) (2026-09-13)


### Features

* **kit:** [#128](https://github.com/Sumit1993/claude-kit/issues/128) adopt Claude Code internals: /autofix-pr first, limit log, resume cost line ([#129](https://github.com/Sumit1993/claude-kit/issues/129)) ([35bbc7e](https://github.com/Sumit1993/claude-kit/commit/35bbc7ee035676785591e46736967a863e7b576a))
* **kit:** triage skill, six skill renames, and the rest of the [#123](https://github.com/Sumit1993/claude-kit/issues/123) rulings ([#132](https://github.com/Sumit1993/claude-kit/issues/132)) ([f1367c1](https://github.com/Sumit1993/claude-kit/commit/f1367c1fee75935e2e69976f7816772dee5b209a))

## [0.9.0](https://github.com/Sumit1993/claude-kit/compare/kit-v0.8.0...kit-v0.9.0) (2026-09-10)


### Features

* **direction:** the skill reads GitHub itself, the script is gone ([#100](https://github.com/Sumit1993/claude-kit/issues/100)) ([#122](https://github.com/Sumit1993/claude-kit/issues/122)) ([3f28806](https://github.com/Sumit1993/claude-kit/commit/3f28806b23b0e2ee6de562c159e840caed2b28d7))
* **kit:** [#123](https://github.com/Sumit1993/claude-kit/issues/123) climb: scratch-path gate, stall refusal, two nudges, length caps, doctrine ([#123](https://github.com/Sumit1993/claude-kit/issues/123)) ([#127](https://github.com/Sumit1993/claude-kit/issues/127)) ([556471c](https://github.com/Sumit1993/claude-kit/commit/556471cbe82a099d88c660c2796aa4db0bf6fd5d))
* **statusline:** 5h and 7d account percent from stdin, traced to metrics/usage.jsonl ([#124](https://github.com/Sumit1993/claude-kit/issues/124)) ([#126](https://github.com/Sumit1993/claude-kit/issues/126)) ([d0cc721](https://github.com/Sumit1993/claude-kit/commit/d0cc7217816c953d3f0f4fd813704926e5bf80b2))


### Bug Fixes

* **agy-delegate:** a quota wall stops agy, not the task, and the spec comes from the planner ([#118](https://github.com/Sumit1993/claude-kit/issues/118)) ([0ded1a1](https://github.com/Sumit1993/claude-kit/commit/0ded1a1432eabb2daafcc2e479e15860b91b93a1))
* **claude-review-lane:** delete a false cancellation diagnostic, and write down the round-scheduling model ([#111](https://github.com/Sumit1993/claude-kit/issues/111)) ([d7aff96](https://github.com/Sumit1993/claude-kit/commit/d7aff96288b0bb1eddf5d33377a68824d4eb42ef))
* **claude-review-lane:** six missing verdicts, the new draft contract, and pause grammar ([#113](https://github.com/Sumit1993/claude-kit/issues/113)) ([16262e2](https://github.com/Sumit1993/claude-kit/commit/16262e2add792b833c110ef8c490da80c4d7fea5))
* **coderabbit-lane:** the star count does not decide whether auto_review fires ([#114](https://github.com/Sumit1993/claude-kit/issues/114)) ([d9e96f3](https://github.com/Sumit1993/claude-kit/commit/d9e96f3592fc00ab46bffe54baabd87a22448312))
* **sync-raw-to-r2:** skip live transcripts and keep going past a failing source ([#124](https://github.com/Sumit1993/claude-kit/issues/124)) ([#125](https://github.com/Sumit1993/claude-kit/issues/125)) ([33b0fbe](https://github.com/Sumit1993/claude-kit/commit/33b0fbe83db435761a57b6651ca1247356e98dee))

## [0.8.0](https://github.com/Sumit1993/claude-kit/compare/kit-v0.7.0...kit-v0.8.0) (2026-09-06)


### Features

* **direction:** one command for where the estate stands and what is next ([#104](https://github.com/Sumit1993/claude-kit/issues/104)) ([f750924](https://github.com/Sumit1993/claude-kit/commit/f750924ba53f6be072bec32c383b3f69c7a7e4fa))
* **scripts:** sync raw run records to R2, query them with DuckDB ([#93](https://github.com/Sumit1993/claude-kit/issues/93)) ([a69ed18](https://github.com/Sumit1993/claude-kit/commit/a69ed18eb097a433ae9fc865467e7d44cb2d4a0c))


### Bug Fixes

* **pr-watch:** classify on CodeRabbit's verdict line, not its boilerplate footer ([#102](https://github.com/Sumit1993/claude-kit/issues/102)) ([1177c24](https://github.com/Sumit1993/claude-kit/commit/1177c244c80b8c17a6131ea17f0922bb1f194ba1)), closes [#101](https://github.com/Sumit1993/claude-kit/issues/101)


### Documentation

* **AGENTS:** Gemini 3.8 Flash Intel 7 to 8 in the model table ([#98](https://github.com/Sumit1993/claude-kit/issues/98)) ([e2ce29b](https://github.com/Sumit1993/claude-kit/commit/e2ce29bd373aaef544d5a16c9e9760edf70cbdd9)), closes [#62](https://github.com/Sumit1993/claude-kit/issues/62)
* **AGENTS:** state what the organizer seat may do, and cap its reports ([#103](https://github.com/Sumit1993/claude-kit/issues/103)) ([49769a7](https://github.com/Sumit1993/claude-kit/commit/49769a7f4ae0067c2cb9208875fba3154722fd11)), closes [#94](https://github.com/Sumit1993/claude-kit/issues/94) [#95](https://github.com/Sumit1993/claude-kit/issues/95) [#97](https://github.com/Sumit1993/claude-kit/issues/97)
* list the direction skill, and remove the root AGENTS.md that was ruled against ([#106](https://github.com/Sumit1993/claude-kit/issues/106)) ([e6bae6d](https://github.com/Sumit1993/claude-kit/commit/e6bae6d3338fc832e7a3f49d848d300320f57989))

## [0.7.0](https://github.com/Sumit1993/claude-kit/compare/kit-v0.6.0...kit-v0.7.0) (2026-09-06)


### Features

* **agy-delegate:** record model and launch metadata in sidecar ([#65](https://github.com/Sumit1993/claude-kit/issues/65)) ([ece63dc](https://github.com/Sumit1993/claude-kit/commit/ece63dc3ee5b9b04cd33a273495d56e6395cb981))
* **scripts:** add check.sh wrapper and rehome audit scripts ([#68](https://github.com/Sumit1993/claude-kit/issues/68)) ([0cce229](https://github.com/Sumit1993/claude-kit/commit/0cce22925abc73612d5bd88414dc1111b74a4ff4))


### Bug Fixes

* **coderabbit-lane:** match doctrine to the Free plan we are actually on ([#76](https://github.com/Sumit1993/claude-kit/issues/76)) ([94655ba](https://github.com/Sumit1993/claude-kit/commit/94655ba88419c9f10ce9b6996e4fac3835d8f7b4)), closes [#73](https://github.com/Sumit1993/claude-kit/issues/73)
* **hooks:** allow quoted heredoc prose in no-broad-agy-kill ([#69](https://github.com/Sumit1993/claude-kit/issues/69)) ([ca64a69](https://github.com/Sumit1993/claude-kit/commit/ca64a699aca0e2388b176a79c2947f98aa526a44))
* **hooks:** close no-haiku gap and scope rule to deliberate choice ([#85](https://github.com/Sumit1993/claude-kit/issues/85)) ([80531f6](https://github.com/Sumit1993/claude-kit/commit/80531f6ce5e9c9e246942b236eb90cf3730818f6)), closes [#77](https://github.com/Sumit1993/claude-kit/issues/77)
* **kit:** five doctrine-drift defects the consistency audit found ([#64](https://github.com/Sumit1993/claude-kit/issues/64)) ([21e1751](https://github.com/Sumit1993/claude-kit/commit/21e1751b5357b48de8c04cef084712cdb48e52c0))
* **pr-watch:** print delta before absolute in retry and rate-limit events ([#84](https://github.com/Sumit1993/claude-kit/issues/84)) ([4baca94](https://github.com/Sumit1993/claude-kit/commit/4baca9420beef74e945bff2bdc65c3fba69150c2))
* **pr-watch:** settle the ALREADY REVIEWED body before emitting it ([#83](https://github.com/Sumit1993/claude-kit/issues/83)) ([dce40b2](https://github.com/Sumit1993/claude-kit/commit/dce40b2052772ff39f4f1e920e0178742c07f591))


### Documentation

* **unattended-run:** clarify absent operator output and grant todos ([#66](https://github.com/Sumit1993/claude-kit/issues/66)) ([1b72210](https://github.com/Sumit1993/claude-kit/commit/1b722103435dea4e719bb8b169f16ff67b6a38ce))


### Tests

* **hooks:** cover the three entries nobody exercised ([#78](https://github.com/Sumit1993/claude-kit/issues/78)) ([91ffca1](https://github.com/Sumit1993/claude-kit/commit/91ffca1b8dbe750595bd121fdc20021d6458c41d))


### Miscellaneous Chores

* **kit:** Fable 5.1 and Gemini 3.8 Flash are the current models ([#63](https://github.com/Sumit1993/claude-kit/issues/63)) ([1fec128](https://github.com/Sumit1993/claude-kit/commit/1fec128929eb275453bcb5a05e93c647d8536092))

## [0.6.0](https://github.com/Sumit1993/claude-kit/compare/kit-v0.5.3...kit-v0.6.0) (2026-09-04)


### Features

* **dotfiles:** deny WebFetch at user scope; context-mode owns fetching ([#59](https://github.com/Sumit1993/claude-kit/issues/59)) ([edc433c](https://github.com/Sumit1993/claude-kit/commit/edc433c5a80d2ac100e6c7745126cdedad612708))


### Documentation

* **AGENTS:** cut to routing and rules, add the issues-are-the-record doctrine ([#38](https://github.com/Sumit1993/claude-kit/issues/38)) ([ce77e27](https://github.com/Sumit1993/claude-kit/commit/ce77e279e0e4b55d6659e54747871b6f5c710e83))
* **agy-delegate:** rules only, stories move to docs/incidents.md ([#39](https://github.com/Sumit1993/claude-kit/issues/39)) ([6e56455](https://github.com/Sumit1993/claude-kit/commit/6e564550ae115c6e5ca9de8bdc079f921983b6fb))
* **anti-stall:** rules only, two stories move to docs/incidents.md ([#40](https://github.com/Sumit1993/claude-kit/issues/40)) ([fec59c7](https://github.com/Sumit1993/claude-kit/commit/fec59c7acb6285b11e301f8aa2b817e949873339))
* **claude-review-lane:** rules only, five stories move to docs/incidents.md ([#42](https://github.com/Sumit1993/claude-kit/issues/42)) ([da3a6f7](https://github.com/Sumit1993/claude-kit/commit/da3a6f7f929b14db7dbf002de82d5fa129727e92))
* **coderabbit-lane:** rules only, six stories move to docs/incidents.md ([#43](https://github.com/Sumit1993/claude-kit/issues/43)) ([4f6f5cd](https://github.com/Sumit1993/claude-kit/commit/4f6f5cdcd3a75782f3143190a8ec175c13c237e8))
* **docs-governance:** tighten prose, keep every rule ([#44](https://github.com/Sumit1993/claude-kit/issues/44)) ([d4b8cec](https://github.com/Sumit1993/claude-kit/commit/d4b8cec41182a3d267a6e598e11c9de825fe64b8))
* **pr-watch:** rules only, three stories move to docs/incidents.md ([#41](https://github.com/Sumit1993/claude-kit/issues/41)) ([aadec1e](https://github.com/Sumit1993/claude-kit/commit/aadec1ef5e62ae0ada78fd8da2e4b5f9d7260360))
* **README:** one line per piece, sections lose their repetition ([#46](https://github.com/Sumit1993/claude-kit/issues/46)) ([5bd0a73](https://github.com/Sumit1993/claude-kit/commit/5bd0a730c1588ddcb54f903aebd0f6e4ce939b52))
* **unattended-run:** rules only, eleven stories move to docs/incidents.md ([#45](https://github.com/Sumit1993/claude-kit/issues/45)) ([5365fe5](https://github.com/Sumit1993/claude-kit/commit/5365fe5e4852e6b97a9654ab7b7b3eebe63a156f))

## [0.5.3](https://github.com/Sumit1993/claude-kit/compare/kit-v0.5.2...kit-v0.5.3) (2026-09-01)


### Bug Fixes

* **claude-review-lane:** a push never verifies, and the verdict has three states ([#34](https://github.com/Sumit1993/claude-kit/issues/34)) ([03a949f](https://github.com/Sumit1993/claude-kit/commit/03a949f089b4fe14deea7475d15cdc7311519bc1))

## [0.5.2](https://github.com/Sumit1993/claude-kit/compare/kit-v0.5.1...kit-v0.5.2) (2026-09-01)


### Bug Fixes

* **coderabbit-lane:** admission is a judgement call, and the counter is per developer ([#32](https://github.com/Sumit1993/claude-kit/issues/32)) ([e056e0e](https://github.com/Sumit1993/claude-kit/commit/e056e0e217fd522a5a3d367a501b1fc2129f9410))

## [0.5.1](https://github.com/Sumit1993/claude-kit/compare/kit-v0.5.0...kit-v0.5.1) (2026-09-01)


### Bug Fixes

* **kit:** misses reported by other sessions ([#28](https://github.com/Sumit1993/claude-kit/issues/28)) ([a7e1f25](https://github.com/Sumit1993/claude-kit/commit/a7e1f25d9dba95f4cf2e4e42fd8d879bbdff069d))

## [0.5.0](https://github.com/Sumit1993/claude-kit/compare/kit-v0.4.0...kit-v0.5.0) (2026-09-01)


### Features

* **dotfiles:** comment-budget rule — constraints inline, stories in docs ([0be4cf4](https://github.com/Sumit1993/claude-kit/commit/0be4cf493a5703d1047d6055cf71b13c75ffc73b))
* **kit:** add the nightly-run skill, drop the fixed lane cap, retrigger agy-delegate on task shape ([#12](https://github.com/Sumit1993/claude-kit/issues/12)) ([6d1d667](https://github.com/Sumit1993/claude-kit/commit/6d1d667a65cdca1d455d079e1cce702525f96169))
* **kit:** add tweet skill — draft session-work tweets for X ([8d4b3c7](https://github.com/Sumit1993/claude-kit/commit/8d4b3c7b5178c1264ed2332886cd0bb2af417e13))
* **kit:** code-over-prompt enforcement layer — registry, gates, pointer routing ([b37398b](https://github.com/Sumit1993/claude-kit/commit/b37398b163fba470c5ee9dcc0333a88a640910b5))
* **kit:** code-over-prompt enforcement layer — registry, gates, pointer routing ([94ac651](https://github.com/Sumit1993/claude-kit/commit/94ac651adadbba6efd415daa0f78d8b61e6f08a6))
* **kit:** docs-governance skill + release gate; consolidate Opus 4.8 to Opus 5 ([0a249d7](https://github.com/Sumit1993/claude-kit/commit/0a249d7e5104b1a9ec3b8fed7fdd96c6dfc3a84d))
* **kit:** publish CLI review evidence when a PR is raised ([#10](https://github.com/Sumit1993/claude-kit/issues/10)) ([cf83e60](https://github.com/Sumit1993/claude-kit/commit/cf83e60be4debf1199ac275a35728e0220d379c1))
* **kit:** queue-era pr-watch — session-scoped watch, claude-lane events, registry lane fields ([b55cf9d](https://github.com/Sumit1993/claude-kit/commit/b55cf9dce73cd49715d941c5202ffce6243a4cf9))
* **kit:** reap watcher processes at session boundaries ([5511dd6](https://github.com/Sumit1993/claude-kit/commit/5511dd632bf06a36255c7d05e87860be7fbf5376))
* **kit:** resolve-verified helper — batch-resolve reviewer-verdicted threads ([#403](https://github.com/Sumit1993/claude-kit/issues/403) design item 3) ([acef1b6](https://github.com/Sumit1993/claude-kit/commit/acef1b6c147d02a55c6c86ffdd2bbb3360453a5d))
* **kit:** tweet skill pulls live voice + dedup context from n8n X Context Provider ([20d64fc](https://github.com/Sumit1993/claude-kit/commit/20d64fcfd7b7362d07ad3e33b88cc95f1978e89b))
* **pr-watch:** detect CodeRabbit auto-pause, do not resume it ([#23](https://github.com/Sumit1993/claude-kit/issues/23)) ([bc452fe](https://github.com/Sumit1993/claude-kit/commit/bc452fe3dcb6d768d13b0346e2d39e208687854d))
* **pr-watch:** probe for CodeRabbit before watching for its reviews ([#1](https://github.com/Sumit1993/claude-kit/issues/1)) ([56b861e](https://github.com/Sumit1993/claude-kit/commit/56b861e8916b71126a590d89f78fe6ea7d5edfbc))
* **scripts:** publish CLI review evidence for the merge gate ([#6](https://github.com/Sumit1993/claude-kit/issues/6)) ([2df4ddb](https://github.com/Sumit1993/claude-kit/commit/2df4ddb302c68d822e2632281af66cd3af13fe25))


### Bug Fixes

* **cr-evidence:** refuse to vouch for a SHA with no completed CLI review ([#8](https://github.com/Sumit1993/claude-kit/issues/8)) ([2ff61b5](https://github.com/Sumit1993/claude-kit/commit/2ff61b59bf3f65933d3331f07070d072e2bee626))
* **install:** jq merge scoping — bind slurped inputs before piping ([01ac767](https://github.com/Sumit1993/claude-kit/commit/01ac76791b0bca2f0f65d20583365e3a1d399484))
* **kit:** CodeRabbit resolution = verified re-review, never blanket resolve for fixed threads ([284c9f0](https://github.com/Sumit1993/claude-kit/commit/284c9f0a7fda12565e595fc8cc81d0fca0301d9d))
* **kit:** repair agy kill/wait mechanics against agy 1.1.22, close pr-watch gaps ([#25](https://github.com/Sumit1993/claude-kit/issues/25)) ([4d2db22](https://github.com/Sumit1993/claude-kit/commit/4d2db221c50843f5233c0b69b4b357889e5ebef7))
* **kit:** repair the rate-limit wait parser, name the 60-minute floor ([#26](https://github.com/Sumit1993/claude-kit/issues/26)) ([86e9240](https://github.com/Sumit1993/claude-kit/commit/86e92402773fd2c2622b25b983de511ee6ad3990))
* **kit:** resolve push target from the command, not session cwd; guard gh api list responses ([#3](https://github.com/Sumit1993/claude-kit/issues/3)) ([048f11e](https://github.com/Sumit1993/claude-kit/commit/048f11e4ace913e9cc53e562600e79e543d143d1))
* **kit:** session-scoped watcher reap, docs-only gate exemption, narrower denies ([845a007](https://github.com/Sumit1993/claude-kit/commit/845a0079829dc9a3a51de8145bff581626803963))
* **pr-watch:** empty-array expansion kept watch/cascade loops alive after all PRs closed ([5a2e707](https://github.com/Sumit1993/claude-kit/commit/5a2e707528b7899260594ce936238ce93b8a8d68))
* **pr-watch:** match the liveness marker by prefix, not the whole string ([bedbc45](https://github.com/Sumit1993/claude-kit/commit/bedbc458ab4d8346c3121450537b4245bcc3a85a))
* **pr-watch:** stop word-splitting CI check names into bogus events ([ab9fcfa](https://github.com/Sumit1993/claude-kit/commit/ab9fcfa0164d206d48a88058580d2a5f5ba6cdab))
* **registry:** correct prismalens code_globs to match .coderabbit.yaml ([#5](https://github.com/Sumit1993/claude-kit/issues/5)) ([13d84f5](https://github.com/Sumit1993/claude-kit/commit/13d84f50365d4970104508c2ecb61d3d841791a4))
* watch-coderabbit reported the inverse of what happened, plus two doctrine corrections ([#24](https://github.com/Sumit1993/claude-kit/issues/24)) ([1dbf7a4](https://github.com/Sumit1993/claude-kit/commit/1dbf7a49aeab9a0f8065589c334df42e07b2fec3))


### Documentation

* **docs-governance:** add the illustration standard ([3db8276](https://github.com/Sumit1993/claude-kit/commit/3db827627de119569123802876eb6488190841bc))
* **docs-governance:** add the illustration standard as governance rule ([1e65398](https://github.com/Sumit1993/claude-kit/commit/1e65398309fd15f5da3b076be34b3a9db4e06ee8))
* document the four review-lane controls from gh-workflows[#7](https://github.com/Sumit1993/claude-kit/issues/7) ([a7adac5](https://github.com/Sumit1993/claude-kit/commit/a7adac57c0542c435d58638fa587a81e7e9f3213))
* **kit:** add the missing cron section to unattended-run, rewrite it plainly ([#22](https://github.com/Sumit1993/claude-kit/issues/22)) ([870b1af](https://github.com/Sumit1993/claude-kit/commit/870b1afaa2e7d140f71cbb301efab2075f2df268))
* **kit:** agy default executor is Gemini 3.7 Flash (released 2026-08-13); 3.6 stays as fallback ([bd791d5](https://github.com/Sumit1993/claude-kit/commit/bd791d595cf95e07e4b33a5f53999c49893c4c94))
* **kit:** correct worktree cleanup rules, pin worktree.baseRef to head ([#19](https://github.com/Sumit1993/claude-kit/issues/19)) ([bf162df](https://github.com/Sumit1993/claude-kit/commit/bf162df33275a6512e172a6db6edf8f4ce86b11c))
* **kit:** name the CodeRabbit label-skip symptom; disambiguate fixer summon vs in-thread replies ([44b1261](https://github.com/Sumit1993/claude-kit/commit/44b126117f44da0520cba9eda18292da072d2f3a))
* **kit:** rename CodeRabbit admission label to coderabbit_review ([0b7b588](https://github.com/Sumit1993/claude-kit/commit/0b7b588b52f70e2d6318678dc54542acfdeb8dd3))
* **kit:** review-process topology — canon serves reusable workflows, copy-sync retired ([e4f554f](https://github.com/Sumit1993/claude-kit/commit/e4f554f3f1fb187fb238a5b7a8610a197a38edb5))
* **kit:** reviewer resolves verified threads, delete local resolver ([#18](https://github.com/Sumit1993/claude-kit/issues/18)) ([927d6eb](https://github.com/Sumit1993/claude-kit/commit/927d6eb8f99fae9bb5d4a728dbcfe541b6a5fcb4))
* **kit:** the review lane's model default and per-run override ([31352a1](https://github.com/Sumit1993/claude-kit/commit/31352a16f6d0041b4d0c1ec6775b733ad11d3edc))
* name the default reviewer, and point worktrees at Claude Code's own ([#15](https://github.com/Sumit1993/claude-kit/issues/15)) ([1b35ccc](https://github.com/Sumit1993/claude-kit/commit/1b35ccc9cca04facab8506108502dd2a1adaebdf))
* PR review & resolution process — living doc for the three-repo review architecture ([e5da39a](https://github.com/Sumit1993/claude-kit/commit/e5da39aa48304335c497fbfc2965a2091a6b10ba))
* sync review-lane docs with today's three merges ([#13](https://github.com/Sumit1993/claude-kit/issues/13)) ([abf96d9](https://github.com/Sumit1993/claude-kit/commit/abf96d95dd06cccc9074c74a0ceda48c4119f33b))


### Code Refactoring

* **kit:** halve CLAUDE.md, split anti-stall into a skill, orchestrator becomes a role ([12bf61a](https://github.com/Sumit1993/claude-kit/commit/12bf61a9c3f1d11caa04c0e145d35cdc42b27323))


### Continuous Integration

* version and release with release-please, add a report-only unslop job ([#29](https://github.com/Sumit1993/claude-kit/issues/29)) ([2aaacd7](https://github.com/Sumit1993/claude-kit/commit/2aaacd7ce22862e1fdcac5a0b83113360316fe72))


### Miscellaneous Chores

* **dotfiles:** CLAUDE.md becomes an import stub over a versioned AGENTS.md ([#9](https://github.com/Sumit1993/claude-kit/issues/9)) ([5741bb0](https://github.com/Sumit1993/claude-kit/commit/5741bb05f1538452404b574c8b4fcb5962d4a365))
* **kit:** narrow the sicko grant, split coderabbit-lane, list tweet ([#17](https://github.com/Sumit1993/claude-kit/issues/17)) ([6a88f43](https://github.com/Sumit1993/claude-kit/commit/6a88f43fd35767b1d098365668254cf313fe07c6))
* **kit:** release 0.4.0, so the install can actually pick up the new hooks ([#27](https://github.com/Sumit1993/claude-kit/issues/27)) ([089911e](https://github.com/Sumit1993/claude-kit/commit/089911e670cc59ceeaa34f0111228333892ca00c))
* **kit:** retire the pre-push CodeRabbit gate ([#11](https://github.com/Sumit1993/claude-kit/issues/11)) ([14ffb31](https://github.com/Sumit1993/claude-kit/commit/14ffb31d362cb667fa9bb99cc6ef7b48ae785eb8))
* **kit:** subscribe to mattpocock/skills as a marketplace instead of file copies ([a0bf290](https://github.com/Sumit1993/claude-kit/commit/a0bf290fa1cee1c9069143c19137f27bfb7155e7))
* vendor four pstack skills, then unslop the repo they document ([#14](https://github.com/Sumit1993/claude-kit/issues/14)) ([9605c1e](https://github.com/Sumit1993/claude-kit/commit/9605c1e59ab8be4252a7b247fbb17efa50234984))
