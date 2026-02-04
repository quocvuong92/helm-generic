# Fix Whitespace Control in _helpers.tpl

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix whitespace control issues in `helm-generic/templates/_helpers.tpl` to match the corrected version in `generic` chart.

**Architecture:** The bug involves incorrect use of Go template whitespace trimming (`{{-` and `-}}`). Two specific lines need correction:
1. Line 138: Missing trailing dash in `{{- end }}` should be `{{- end -}}`
2. Line 424: Extra trailing dash in `{{- end -}}` should be `{{- end }}`

**Tech Stack:** Helm, Go templates

---

## Context

The `generic` chart has been updated with a fix for whitespace control issues. The `helm-generic` chart still has the buggy version. The fix ensures proper YAML formatting is generated in all scenarios.

**Bug Details:**
- Line 138 (in `generic.annotations` definition): Missing `-` causes extra whitespace when globalAnnotations are processed
- Line 424 (in `generic.podSpec` definition): Extra `-` trims the newline after imagePullSecrets, potentially causing YAML formatting issues

---

### Task 1: Verify Current State

**Files:**
- Read: `helm-generic/templates/_helpers.tpl:135-140`
- Read: `helm-generic/templates/_helpers.tpl:420-426`
- Reference: `generic/templates/_helpers.tpl:135-140`
- Reference: `generic/templates/_helpers.tpl:420-426`

**Step 1: Check current buggy state in helm-generic**

Verify line 138 shows `{{- end }}` (missing dash).

**Step 2: Check current buggy state at line 424**

Verify line 424 shows `{{- end -}}` (extra dash).

**Step 3: Verify reference implementation in generic**

Confirm:
- Line 138: `{{- end -}}` (has dash)
- Line 424: `{{- end }}` (no dash)

---

### Task 2: Fix Line 138 - Add Missing Trailing Dash

**Files:**
- Modify: `helm-generic/templates/_helpers.tpl:138`

**Step 1: Apply the fix**

Change:
```
{{- end }}
```
To:
```
{{- end -}}
```

**Step 2: Verify the change**

Run: `grep -n "{{- end }}" helm-generic/templates/_helpers.tpl | head -5`
Expected: Line 138 should NOT appear in output (it now has `-}}`)

---

### Task 3: Fix Line 424 - Remove Extra Trailing Dash

**Files:**
- Modify: `helm-generic/templates/_helpers.tpl:424`

**Step 1: Apply the fix**

Change:
```
{{- end -}}
```
To:
```
{{- end }}
```

**Step 2: Verify the change**

Run: `sed -n '424p' helm-generic/templates/_helpers.tpl`
Expected: Shows `{{- end }}` (without trailing dash)

---

### Task 4: Verify Files Match

**Files:**
- Compare: `generic/templates/_helpers.tpl` vs `helm-generic/templates/_helpers.tpl`

**Step 1: Run diff**

Run: `diff generic/templates/_helpers.tpl helm-generic/templates/_helpers.tpl`
Expected: No output (exit code 0)

**Step 2: Confirm with exit code**

Run: `diff generic/templates/_helpers.tpl helm-generic/templates/_helpers.tpl; echo "Exit code: $?"`
Expected: `Exit code: 0`

---

### Task 5: Test Helm Template Rendering

**Files:**
- Test with: `helm-generic/values.yaml`

**Step 1: Validate template syntax**

Run: `cd helm-generic && helm lint .`
Expected: `1 chart(s) linted, 0 chart(s) failed`

**Step 2: Test template rendering with imagePullSecrets**

Run: `cd helm-generic && helm template test-release . --set imagePullSecrets[0].name=my-secret -s templates/deployment.yaml | head -30`
Expected: Valid YAML output with proper formatting around imagePullSecrets

---

### Task 6: Commit Changes

**Step 1: Stage changes**

```bash
git add helm-generic/templates/_helpers.tpl
```

**Step 2: Commit with descriptive message**

```bash
git commit -m "fix: correct whitespace control in _helpers.tpl

Fix two whitespace control issues in Go templates:
- Line 138: Add missing trailing dash to trim whitespace after globalAnnotations
- Line 424: Remove extra trailing dash to preserve newline after imagePullSecrets

This ensures proper YAML formatting in all scenarios when
imagePullSecrets or globalAnnotations are used."
```

---

## Verification Checklist

- [ ] Line 138 changed from `{{- end }}` to `{{- end -}}`
- [ ] Line 424 changed from `{{- end -}}` to `{{- end }}`
- [ ] `diff generic/templates/_helpers.tpl helm-generic/templates/_helpers.tpl` shows no differences
- [ ] `helm lint` passes
- [ ] `helm template` renders valid YAML
