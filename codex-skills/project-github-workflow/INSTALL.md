# Install on another computer

Copy the complete `project-github-workflow` directory into the Codex user skills directory, then start a new Codex conversation so the skill catalog is reloaded.

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force "$HOME\.codex\skills" | Out-Null
Copy-Item -Recurse -Force .\codex-skills\project-github-workflow "$HOME\.codex\skills\project-github-workflow"
```

macOS or Linux:

```bash
mkdir -p ~/.codex/skills
cp -R ./codex-skills/project-github-workflow ~/.codex/skills/project-github-workflow
```

Keep the folder name `project-github-workflow`. Automatic discovery is enabled, and the skill can also be invoked explicitly as `$project-github-workflow`.
