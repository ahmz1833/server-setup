# Agent Guidelines & Release Workflow

All agents and contributors working on this repository **must strictly adhere to the following rules**.

---

## 1. Documentation & Metadata Consistency (Mandatory)

Always keep all metadata and documentation strictly synchronized with code changes:
- **Role Defaults & Metadata**: Whenever variables or features are added, updated, or deprecated, immediately update the corresponding role's `defaults/main.yml`, `meta/main.yml`, and relevant templates.
- **Role & Root Documentation**: Keep role-specific `README.md` files, root `README.md`, and playbook examples in `examples/` fully aligned with actual configuration parameters and default values.
- **Holistic Integrity**: Update all affected references across the project whenever introducing new behaviors to prevent stale documentation or orphan configurations.

---

## 2. Commit, Versioning & Release Workflow

Follow this disciplined lifecycle for every fix, feature, or release:

### A. Incremental & Conventional Commits
- Break changes into clean, atomic commits scoped by domain (e.g., `fix(k3s): ...`, `feat(node): ...`, `docs(changelog): ...`).
- Avoid mixing unrelated multi-role changes into a single ambiguous commit.

### B. Version Bumping & Changelog Updates
- **`galaxy.yml`**: Bump the semantic version (e.g., increment patch version for fixes and iterative enhancements).
- **`CHANGELOG.md`**: Maintain an accurate, up-to-date changelog. Every release and merged PR/MR **must** have its corresponding entry under `## [X.Y.Z] - YYYY-MM-DD` detailing `### Added`, `### Fixed`, or `### Changed` items. Never bump versions or merge changes without updating `CHANGELOG.md`.

### C. Git Tagging
- Tag every release commit with the matching version tag:
  ```bash
  git tag v<major>.<minor>.<patch>
  ```
  *(e.g., `git tag v1.4.3`)*

---

## 3. Verification & Cleanliness
- Validate YAML / Jinja2 syntax before committing.
- Ensure the working tree is clean and no unintended files or scratch artifacts remain.
