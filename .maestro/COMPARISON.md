# UI Testing Framework Comparison: XCTest vs Maestro

## Overview

This document compares the two UI testing approaches used in Nostos to help decide which framework best serves the project's needs.

## Test Count & Coverage

| Framework | Test Files | Test Cases | Coverage |
|-----------|-----------|------------|----------|
| XCTest | 1 Swift file | 14 test methods | Full app coverage |
| Maestro | 12 YAML files | 12 test flows | ~86% parity with XCTest |

**Missing from Maestro:**
- `testScannerChooseDirectoryButtonUpdatesPath()` - Complex path mocking
- `testScannerStartScanButtonInitiatesScan()` - Scanning state verification

## Code Comparison

### Tab Navigation Test

**XCTest** (11 lines of Swift code):
```swift
func testTabNavigation() {
    el("galleryPhotoTile")
    goToTab("scannerTabButton")
    el("scannerStartScanButton")
    goToTab("duplicatesTabButton")
    el("duplicatesKeepFirstButton")
    goToTab("vaultTabButton")
    el("vaultChangeVaultButton")
    goToTab("galleryTabButton")
    el("galleryPhotoTile")
}
```

**Maestro** (40 lines of YAML):
```yaml
- assertVisible:
    id: "galleryPhotoTile"
- tapOn:
    id: "scannerTabButton"
- assertVisible:
    id: "scannerStartScanButton"
# ... etc
```

**Winner:** XCTest for conciseness (due to helper methods), but Maestro for clarity and self-documentation.

## Metrics Comparison

### Readability
- **XCTest:** 6/10 - Requires understanding of Swift and XCTest API
- **Maestro:** 9/10 - YAML is readable by non-developers

### Maintainability
- **XCTest:** 7/10 - Changes require Swift knowledge and recompilation
- **Maestro:** 9/10 - Edit YAML and run immediately

### Debugging
- **XCTest:** 9/10 - Full Xcode debugger, breakpoints, accessibility inspector
- **Maestro:** 6/10 - Screenshots and logs, but no interactive debugger

### Setup Complexity
- **XCTest:** 10/10 - Built into Xcode, no installation needed
- **Maestro:** 7/10 - One-time CLI installation required

### Execution Speed
- **XCTest:** ~45s startup + ~2s per test = ~1m total
- **Maestro:** TBD (requires actual execution)

### CI Integration
- **XCTest:** 10/10 - Already integrated in `.github/workflows/swift.yml`
- **Maestro:** 8/10 - Requires adding Maestro install step

### Test Writing Speed
- **XCTest:** 6/10 - Write Swift → compile → run cycle
- **Maestro:** 10/10 - Edit YAML → run immediately

## Real-World Usage Scenarios

### Scenario 1: Developer fixing a bug in Gallery filters

**XCTest:**
1. Open `NostosUITests.swift` in Xcode
2. Find `testGallerySidebarDuplicateFilters()`
3. Add new assertion
4. Build test target (~10s)
5. Run test

**Maestro:**
1. Open `05-gallery-sidebar-filters.yaml`
2. Add new step (e.g., `- tapOn: {id: "newFilter"}`)
3. Run `maestro test .maestro/05-gallery-sidebar-filters.yaml`

**Winner:** Maestro (no compilation)

### Scenario 2: QA engineer verifying a feature

**XCTest:**
- Requires Swift knowledge or developer assistance
- Must understand XCTest API
- Cannot easily modify tests

**Maestro:**
- Can read YAML tests to understand flow
- Can modify/add tests with basic YAML knowledge
- Can run tests without Xcode

**Winner:** Maestro (accessibility)

### Scenario 3: Debugging a failing test

**XCTest:**
- Set breakpoint in test code
- Inspect `app.debugDescription` for hierarchy
- Step through with debugger
- Check element properties in real-time

**Maestro:**
- Check failure screenshot in `~/.maestro/tests/`
- Add `--debug-output` flag for verbose logs
- Use `maestro studio` for interactive exploration

**Winner:** XCTest (better debugging tools)

### Scenario 4: Testing across macOS versions

**XCTest:**
- Requires different Xcode versions
- Must maintain compatibility
- Accessibility APIs may change

**Maestro:**
- Same YAML works across versions
- CLI handles compatibility
- Easier to test on multiple environments

**Winner:** Maestro (cross-version testing)

## Qualitative Observations

### XCTest Strengths
1. Helper methods (`el()`, `goToTab()`, `notPresent()`) make tests concise
2. Full Swift power for complex assertions
3. Can access app state through accessibility
4. Integrated into existing development workflow
5. No external dependencies

### XCTest Weaknesses
1. Tests are code, not documentation
2. Requires compilation for every change
3. Steep learning curve for non-developers
4. Verbose async/await handling

### Maestro Strengths
1. Tests are self-documenting
2. No compilation step
3. Excellent for rapid iteration
4. Non-technical team members can contribute
5. Better failure screenshots
6. Cross-platform potential

### Maestro Weaknesses
1. Cannot access Swift APIs
2. Less precise control
3. External dependency
4. Smaller community/ecosystem
5. Some scenarios harder to express in YAML

## Cost-Benefit Analysis

### Initial Setup Cost
- **XCTest:** ✅ Free (already done)
- **Maestro:** ⚠️ Medium (~2 hours to create 12 flows)

### Ongoing Maintenance
- **XCTest:** Medium (requires Swift dev for changes)
- **Maestro:** Low (anyone can edit YAML)

### Team Productivity
- **XCTest:** Good (developers only)
- **Maestro:** Excellent (whole team can participate)

### Test Coverage Value
- **XCTest:** High (catches real bugs)
- **Maestro:** High (same coverage, different approach)

## Recommendations

### Keep Both For Now
Run this comparison for **2-3 months** to evaluate:
1. Which tests catch bugs first
2. Which are easier to maintain when UI changes
3. Team preference and contribution patterns
4. CI execution time differences

### Long-Term Strategy Options

**Option A: XCTest Only**
- If team is developer-heavy
- If debugging features are critical
- If external dependencies are a concern
- **Best for:** Small teams, complex UI logic

**Option B: Maestro Only**
- If tests are mostly smoke tests
- If non-developers need to write tests
- If rapid iteration is priority
- **Best for:** Larger teams, regression testing

**Option C: Hybrid Approach**
- XCTest for complex scenarios requiring debugging
- Maestro for simple smoke tests and regression
- **Best for:** Most teams (recommended)

**Option D: Gradual Migration to Maestro**
- Write all new tests in Maestro
- Port XCTest only when they need updates
- **Best for:** Long-term Maestro adoption

## Next Steps

1. ✅ Set up both test suites (complete)
2. ⏳ Run both in parallel for 2-3 months
3. ⏳ Track metrics:
   - Test execution time
   - Maintenance effort
   - Bug detection rate
   - Team contribution patterns
4. ⏳ Make data-driven decision on long-term strategy

## Conclusion

**For Nostos specifically:**

Given that Nostos is a single-developer project with comprehensive XCTest coverage, **Maestro adds value primarily as a learning tool and potential future investment**. The self-documenting nature of YAML tests could be valuable if the project grows a community or onboards contributors.

**Recommendation:** Continue running both test suites for now. If maintenance burden becomes high, prioritize XCTest. If the project attracts non-developer contributors, invest more in Maestro.
