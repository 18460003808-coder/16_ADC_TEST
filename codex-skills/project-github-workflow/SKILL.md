---
name: project-github-workflow
description: Manage Git and GitHub checkpoints when Codex creates or updates an engineering or software project. Use for new project scaffolding, project file changes, commits, or GitHub publication; ask about GitHub setup at project start, create task-scoped commits after verified changes, and require explicit approval for every push. Do not use for read-only questions with no project changes.
---

# Project GitHub Workflow

Keep local version history automatic and remote publication user-controlled.

## Starting a project

At the beginning of a new project, before implementation:

1. Check whether the directory is already a Git repository and whether a remote is configured.
2. Ask whether the user wants to create or connect a GitHub repository.
3. If yes, obtain any missing material choices such as owner, repository name, visibility, and whether to use an existing repository.
4. Do not create a GitHub repository, add a remote, publish files, or push until the user explicitly approves that external action.

If the user declines GitHub setup, continue locally when appropriate. Do not repeatedly ask during the same project setup unless the user reopens the choice.

## Completing a project update

After requested file changes are complete and proportionately verified:

1. Review `git status` and the relevant diff.
2. Preserve unrelated user changes. Stage only the current task's changes unless the user explicitly asks to include other work.
3. Create one concise, task-scoped commit. Do not create a success commit for incomplete or failed work unless the user explicitly requests a work-in-progress commit.
4. Report the commit hash, commit message, verification performed, and any remaining uncommitted changes.

If the directory is not a Git repository, ask whether to initialize one instead of doing so silently.

## GitHub push approval gate

After each new commit, ask whether the user wants that commit uploaded to the configured GitHub remote. Include the target remote and branch when known.

- Do not run `git push` before the user approves that specific update.
- Approval for an earlier commit or task does not authorize later pushes.
- If the current user request explicitly says to push or upload the resulting update, that is the approval for that update; do not ask redundantly unless the destination or branch is ambiguous.
- Never use force push, rewrite remote history, create a public repository, or change repository visibility without separate explicit authorization.

Before the first publication, check for obvious secrets and GitHub's single-file size limit. Do not silently remove generated artifacts or large files; explain the issue and ask how the user wants to handle it.

If a push times out or disconnects, query the remote branch before retrying. Retry only when the remote does not contain the commit, using the same remote, branch, and commit. Report the result rather than claiming success from ambiguous output.

## Final report

Distinguish clearly between:

- local commit created;
- push requested but not yet approved;
- push completed and remote commit verified.

Do not imply that a local commit is already backed up on GitHub.
