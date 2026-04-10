---
description: "General coding standards for readability, maintainability, and safe automation changes."
name: "Coding Standards"
applyTo: "Vagrantfile, Makefile, **/*.yml, **/*.yaml, **/*.ps1, **/*.sh"
---

# Coding Standards

## Core Principles

- Prefer clear, maintainable code over clever one-liners.
- Keep changes small, focused, and easy to review.
- Preserve idempotent behavior for provisioning and automation tasks.
- Prefer clear, deterministic scripting over dense imperative command chains.

## Bash and Shell Rules

- Do not write long Bash commands.
- Keep each Bash command short and readable; target one action per line.
- If a command becomes long or complex, split it across lines with continuation, use variables, or move logic into a small script/function.
- Avoid dense pipelines that are hard to debug; prefer intermediate variables with clear names.
- Add `set -euo pipefail` in scripts unless there is a documented reason not to.
- Use { ... } or functions to logically group related commands for shared redirection or error handling.

## Naming and Structure

- Use descriptive names for variables, tasks, and functions.
- Keep files and folders organized by purpose.
- Avoid large monolithic scripts; extract reusable logic into roles, tasks, or helper scripts.

## Comments and Documentation

- Add comments only where intent is not obvious.
- Explain non-trivial decisions and environment assumptions.
- Keep runbooks and README snippets aligned with actual behavior.

## Safety and Reliability

- Validate inputs and fail fast with helpful errors.
- Avoid destructive operations unless explicitly required and documented.
- Prefer repeatable, deterministic operations and stable defaults.

## Review Expectations

- Every change should be easy to test locally.
- Verify linting or syntax checks where available.
- Include concise rationale in commit or PR descriptions for non-obvious changes.
