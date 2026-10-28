/**
 * scripts/check-apex-tests.js
 * 
 * Enforces test class pairing and extracts test classes to run:
 * 1. Scans delta changes (or source files) for modified/added Apex classes.
 * 2. Distinguishes source classes from test classes (using naming patterns & @isTest).
 * 3. Checks that EVERY source class has a corresponding test class:
 *    - In the delta package (PR changed files), OR
 *    - Mentioned in the git commit message(s) / PR description.
 * 4. If any source class is missing a test class:
 *    - FAILS the build with a clear, formatted error message and fix instructions.
 * 5. If all classes have test coverage:
 *    - Outputs the list of test classes to run (for RunSpecifiedTests).
 *    - If no Apex code changed at all, outputs NoTestRun.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Parse CLI flags
const args = process.argv.slice(2);
let deltaDir = 'changed-sources/force-app';
let baseRef = '';
let headRef = 'HEAD';
let mode = 'pr'; // 'pr' or 'deploy'

for (let i = 0; i < args.length; i++) {
    if (args[i] === '--delta-dir' && args[i + 1]) deltaDir = args[++i];
    if (args[i] === '--base-ref' && args[i + 1]) baseRef = args[++i];
    if (args[i] === '--head-ref' && args[i + 1]) headRef = args[++i];
    if (args[i] === '--mode' && args[i + 1]) mode = args[++i];
}

// Helper: recursively find all files with given extension in a directory
function findFiles(dir, ext, fileList = []) {
    if (!fs.existsSync(dir)) return fileList;
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            findFiles(fullPath, ext, fileList);
        } else if (entry.name.endsWith(ext)) {
            fileList.push(fullPath);
        }
    }
    return fileList;
}

// Helper: check if an Apex class is a test class
function isTestClass(filePath) {
    const fileName = path.basename(filePath, '.cls');
    if (/Test$|_Test$|Tests$|_Tests$/i.test(fileName)) {
        return true;
    }
    try {
        const content = fs.readFileSync(filePath, 'utf8');
        if (/@isTest/i.test(content)) {
            return true;
        }
    } catch (e) {
        // ignore read errors
    }
    return false;
}

// Helper: get commit messages between base and head
function getCommitMessages() {
    let messages = '';
    try {
        if (baseRef) {
            messages = execSync(`git log ${baseRef}..${headRef} --format="%B"`, { encoding: 'utf8' });
        } else {
            messages = execSync(`git log -n 5 --format="%B"`, { encoding: 'utf8' });
        }
    } catch (e) {
        try {
            messages = execSync(`git log -1 --format="%B"`, { encoding: 'utf8' });
        } catch (err) {
            messages = '';
        }
    }
    // Also read pr_body.txt if present
    if (fs.existsSync('pr_body.txt')) {
        try {
            messages += '\n' + fs.readFileSync('pr_body.txt', 'utf8');
        } catch (e) {}
    }
    return messages;
}

// Helper: get all existing test class names in the repository
function getAllExistingTestClasses() {
    const classesDir = path.join(process.cwd(), 'force-app', 'main', 'default', 'classes');
    const existing = new Set();
    if (fs.existsSync(classesDir)) {
        const files = fs.readdirSync(classesDir);
        for (const f of files) {
            if (f.endsWith('.cls')) {
                const name = f.replace('.cls', '');
                if (/Test$|_Test$|Tests$|_Tests$/i.test(name)) {
                    existing.add(name);
                }
            }
        }
    }
    return existing;
}

function run() {
    console.log('================================================================================');
    console.log(`🔍 APEX TEST CLASS DETECTOR & VALIDATOR (${mode.toUpperCase()} MODE)`);
    console.log('================================================================================');

    const searchDir = fs.existsSync(deltaDir) ? deltaDir : 'changed-sources';
    const changedClsFiles = findFiles(searchDir, '.cls');

    if (changedClsFiles.length === 0) {
        console.log('ℹ️  No Apex (.cls) files detected in the delta package.');
        console.log('👉 Setting test level: NoTestRun');
        exportOutputs('NoTestRun', '', false);
        return;
    }

    console.log(`Found ${changedClsFiles.length} Apex (.cls) file(s) in delta package:`);
    changedClsFiles.forEach(f => console.log(`   - ${path.relative(process.cwd(), f)}`));

    const sourceClasses = [];
    const changedTestClasses = new Set();

    for (const file of changedClsFiles) {
        const className = path.basename(file, '.cls');
        if (isTestClass(file)) {
            changedTestClasses.add(className);
        } else {
            sourceClasses.push({ name: className, path: file });
        }
    }

    console.log(`\n📦 Source Classes (${sourceClasses.length}): ${sourceClasses.map(c => c.name).join(', ') || 'None'}`);
    console.log(`🧪 Changed Test Classes (${changedTestClasses.size}): ${Array.from(changedTestClasses).join(', ') || 'None'}`);

    const commitMessages = getCommitMessages();
    const existingRepoTests = getAllExistingTestClasses();
    const finalTestsToRun = new Set(changedTestClasses);

    // Look for test classes explicitly mentioned in commit messages
    // Format could be:
    // [Test: MyTestClass] or Tests: MyTestClass, OtherTestClass or mentioning TestClass
    for (const testName of existingRepoTests) {
        const regex = new RegExp(`\\b${testName}\\b`, 'i');
        if (regex.test(commitMessages)) {
            finalTestsToRun.add(testName);
            console.log(`📝 Detected test class in commit message/PR body: ${testName}`);
        }
    }

    // Now verify that EVERY source class has an associated test class
    const missingTests = [];

    for (const src of sourceClasses) {
        const name = src.name;
        // Common conventions:
        const expected1 = `${name}Test`;
        const expected2 = `${name}_Test`;
        const expected3 = `${name}Tests`;
        // If name ends in Controller, check without Controller as well (e.g. RSOCL_ApprovalProcessedDataController -> RSOCL_ApprovalProcessedDataTest)
        const expectedWithoutController = name.endsWith('Controller') ? `${name.replace(/Controller$/, '')}Test` : '';

        let matchedTest = null;

        // 1. Check in tests to run (which includes changed tests + commit mentioned tests)
        for (const t of finalTestsToRun) {
            if (
                t.toLowerCase() === expected1.toLowerCase() ||
                t.toLowerCase() === expected2.toLowerCase() ||
                t.toLowerCase() === expected3.toLowerCase() ||
                (expectedWithoutController && t.toLowerCase() === expectedWithoutController.toLowerCase())
            ) {
                matchedTest = t;
                break;
            }
        }

        // 2. Check if any test class file in the delta imports or mentions this source class
        if (!matchedTest) {
            for (const t of changedTestClasses) {
                const testFilePath = changedClsFiles.find(f => path.basename(f, '.cls') === t);
                if (testFilePath) {
                    try {
                        const content = fs.readFileSync(testFilePath, 'utf8');
                        if (new RegExp(`\\b${name}\\b`).test(content)) {
                            matchedTest = t;
                            break;
                        }
                    } catch (e) {}
                }
            }
        }

        if (matchedTest) {
            console.log(`   ✅ ${name}.cls -> Paired with ${matchedTest}`);
        } else {
            missingTests.push({
                sourceClass: `${name}.cls`,
                expectedTest: `${expected1}.cls`
            });
        }
    }

    // Check if any source classes failed pairing
    if (missingTests.length > 0) {
        console.log('\n================================================================================');
        console.log('❌ BUILD FAILED: Missing Apex Test Classes!');
        console.log('================================================================================');
        console.log('Every modified Apex class must have a corresponding test class included in the');
        console.log('PR components OR referenced in the commit message.\n');
        console.log('The following Apex class(es) do not have a matching test class:');
        console.log('┌──────────────────────────────────────────────┬──────────────────────────────────────────────────────┐');
        console.log('│ Apex Class                                   │ Expected / Suggested Test Class                      │');
        console.log('├──────────────────────────────────────────────┼──────────────────────────────────────────────────────┤');
        for (const item of missingTests) {
            const col1 = item.sourceClass.padEnd(44, ' ');
            const col2 = item.expectedTest.padEnd(52, ' ');
            console.log(`│ ${col1} │ ${col2} │`);
        }
        console.log('└──────────────────────────────────────────────┴──────────────────────────────────────────────────────┘');
        console.log('\n💡 HOW TO RESOLVE:');
        console.log('   1. Include the test class in your Pull Request:');
        console.log('      e.g., force-app/main/default/classes/' + missingTests[0].expectedTest);
        console.log('   2. OR if the test class already exists in the target org, mention it in your commit message:');
        console.log('      git commit -m "Update ' + missingTests[0].sourceClass.replace('.cls', '') + ' [Test: ' + missingTests[0].expectedTest.replace('.cls', '') + ']"');
        console.log('================================================================================\n');
        process.exit(1);
    }

    const testList = Array.from(finalTestsToRun);
    if (testList.length === 0) {
        console.log('⚠️  No test classes found to run.');
        exportOutputs('NoTestRun', '', true);
    } else {
        console.log(`\n🎯 Test Classes to execute (${testList.length}):`);
        testList.forEach(t => console.log(`   - ${t}`));
        exportOutputs('RunSpecifiedTests', testList.join(','), true);
    }
}

function exportOutputs(testLevel, tests, hasApex) {
    console.log(`\n📋 Final Configuration:`);
    console.log(`   TEST_LEVEL   : ${testLevel}`);
    console.log(`   TESTS_TO_RUN : ${tests || '(none)'}`);
    console.log(`   HAS_APEX     : ${hasApex}`);

    // Write testsToRun.txt file
    fs.writeFileSync('testsToRun.txt', tests);

    // Export to GitHub Actions environment / output if available
    const envFile = process.env.GITHUB_ENV;
    if (envFile && fs.existsSync(envFile)) {
        fs.appendFileSync(envFile, `TEST_LEVEL=${testLevel}\n`);
        fs.appendFileSync(envFile, `TESTS_TO_RUN=${tests}\n`);
        fs.appendFileSync(envFile, `HAS_APEX=${hasApex}\n`);
    }

    const outputFile = process.env.GITHUB_OUTPUT;
    if (outputFile && fs.existsSync(outputFile)) {
        fs.appendFileSync(outputFile, `test_level=${testLevel}\n`);
        fs.appendFileSync(outputFile, `tests_to_run=${tests}\n`);
        fs.appendFileSync(outputFile, `has_apex=${hasApex}\n`);
    }
    console.log('================================================================================\n');
}

run();
