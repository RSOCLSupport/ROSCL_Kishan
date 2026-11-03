/**
 * scripts/check-code-coverage.js
 * 
 * Analyzes Salesforce deployment / test execution JSON output:
 * 1. Verifies that all test methods passed (numFailures === 0).
 * 2. Calculates code coverage for each Apex class and overall test run.
 * 3. Enforces the minimum required code coverage threshold (default: 80%).
 * 4. Outputs a clear table and fails the build if coverage < threshold.
 */

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
let resultFile = 'deploy-result.json';
let threshold = 80;

for (let i = 0; i < args.length; i++) {
    if (args[i] === '--file' && args[i + 1]) resultFile = args[++i];
    if (args[i] === '--threshold' && args[i + 1]) threshold = parseFloat(args[++i]);
}

if (!fs.existsSync(resultFile)) {
    console.error(`❌ Deploy result file "${resultFile}" not found. Skipping code coverage verification.`);
    process.exit(1);
}

let data;
try {
    const raw = fs.readFileSync(resultFile, 'utf8');
    data = JSON.parse(raw);
} catch (e) {
    console.error(`❌ Failed to parse deploy result JSON from ${resultFile}: ${e.message}`);
    process.exit(1);
}

// Navigate through possible JSON structures (sf vs sfdx)
const result = data.result || data;

// 1. Verify deployment status against target org
const isDeployFailed = 
    (data.status !== undefined && data.status !== 0) ||
    data.exitCode === 1 ||
    data.name === 'FailedValidationError' ||
    data.code === 'FailedValidationError' ||
    (result.status && result.status !== 'Succeeded' && result.status !== 'SucceededPartial') ||
    result.success === false;

if (isDeployFailed) {
    console.log('================================================================================');
    console.log('❌ BUILD FAILED: Deployment / validation against the target org failed.');
    console.log('================================================================================');
    if (data.message) {
        console.error(`\nError Details:\n${data.message}\n`);
    }
    const componentFailures = result.details?.componentFailures;
    if (Array.isArray(componentFailures) && componentFailures.length > 0) {
        console.log(`Component Failures (${componentFailures.length}):`);
        componentFailures.forEach((f, idx) => {
            const compType = f.componentType || 'Component';
            const name = f.fileName || f.fullName || 'Unknown';
            const problem = f.problem || 'Unknown error';
            console.log(`   [${idx + 1}] ${compType}: ${name} -> ${problem}`);
        });
        console.log('');
    }
    console.log('================================================================================\n');
    process.exit(1);
}

const testResult = result.details?.runTestResult || result.runTestResult;

if (!testResult) {
    console.log('ℹ️  No Apex test results found in deployment output (NoTestRun was used).');
    process.exit(0);
}

console.log('================================================================================');
console.log('📊 SALESFORCE APEX TEST EXECUTION & CODE COVERAGE REPORT');
console.log('================================================================================');
console.log(`Tests Run      : ${testResult.numTestsRun ?? 0}`);
console.log(`Tests Failed   : ${testResult.numFailures ?? 0}`);
console.log(`Execution Time : ${testResult.totalTime ? (testResult.totalTime / 1000).toFixed(2) + 's' : 'N/A'}`);
console.log(`Required Minimum Coverage : ${threshold}%\n`);

// 1. Check for test failures
if (testResult.numFailures > 0) {
    console.log('❌ TEST FAILURES DETECTED:');
    const failures = Array.isArray(testResult.failures) ? testResult.failures : [testResult.failures];
    failures.forEach((f, idx) => {
        console.log(`\n  [Failure ${idx + 1}]`);
        console.log(`  Test Class  : ${f.name}`);
        console.log(`  Test Method : ${f.methodName}`);
        console.log(`  Message     : ${f.message}`);
        if (f.stackTrace) console.log(`  Stack Trace : ${f.stackTrace}`);
    });
    console.log('\n================================================================================');
    console.log('❌ BUILD FAILED: One or more Apex unit tests failed.');
    console.log('================================================================================\n');
    process.exit(1);
}

// 2. Check code coverage
const coverages = testResult.codeCoverage;
if (!coverages || (Array.isArray(coverages) && coverages.length === 0)) {
    console.log('⚠️  No code coverage data returned for the executed tests.');
    process.exit(0);
}

const coverageList = Array.isArray(coverages) ? coverages : [coverages];

let totalLocations = 0;
let totalLocationsNotCovered = 0;
let classesBelowThreshold = [];

console.log('┌──────────────────────────────────────────────┬────────────┬─────────────┬──────────┬────────┐');
console.log('│ Apex Class                                   │ Total Lines│ Lines Cover │ Coverage │ Status │');
console.log('├──────────────────────────────────────────────┼────────────┼─────────────┼──────────┼────────┤');

for (const cov of coverageList) {
    const name = cov.name || 'Unknown';
    const numLoc = parseInt(cov.numLocations || 0, 10);
    const numNotCov = parseInt(cov.numLocationsNotCovered || 0, 10);
    const numCovered = Math.max(0, numLoc - numNotCov);

    totalLocations += numLoc;
    totalLocationsNotCovered += numNotCov;

    const percent = numLoc > 0 ? (numCovered / numLoc) * 100 : 100;
    const isPassing = percent >= threshold;

    if (!isPassing) {
        classesBelowThreshold.push({ name, percent, numLoc, numCovered });
    }

    const colName = name.padEnd(44, ' ');
    const colTotal = String(numLoc).padStart(10, ' ');
    const colCovered = String(numCovered).padStart(11, ' ');
    const colPercent = (percent.toFixed(1) + '%').padStart(8, ' ');
    const colStatus = isPassing ? '  PASS  ' : '  FAIL  ';

    console.log(`│ ${colName} │ ${colTotal} │ ${colCovered} │ ${colPercent} │ ${colStatus} │`);
}

console.log('└──────────────────────────────────────────────┴────────────┴─────────────┴──────────┴────────┘');

const totalCovered = totalLocations - totalLocationsNotCovered;
const overallCoverage = totalLocations > 0 ? (totalCovered / totalLocations) * 100 : 100;

console.log(`\n📈 SUMMARY:`);
console.log(`   Total Executable Lines : ${totalLocations}`);
console.log(`   Total Covered Lines    : ${totalCovered}`);
console.log(`   Overall Code Coverage  : ${overallCoverage.toFixed(2)}%`);

if (overallCoverage < threshold || classesBelowThreshold.length > 0) {
    console.log('\n================================================================================');
    console.log('❌ BUILD FAILED: Code Coverage Below Required Threshold!');
    console.log('================================================================================');
    console.log(`Required minimum coverage: ${threshold}%`);
    console.log(`Overall coverage achieved: ${overallCoverage.toFixed(2)}%\n`);

    if (classesBelowThreshold.length > 0) {
        console.log('The following class(es) do not meet the 80% coverage threshold:');
        classesBelowThreshold.forEach(c => {
            console.log(`   - ${c.name}: ${c.percent.toFixed(1)}% (${c.numCovered}/${c.numLoc} lines)`);
        });
    }

    console.log('\n💡 HOW TO RESOLVE:');
    console.log('   Add more test methods covering conditional branches, exception handlers,');
    console.log('   and edge cases until coverage is at least 80% for every class.');
    console.log('================================================================================\n');
    process.exit(1);
}

console.log('\n================================================================================');
console.log(`✅ CODE COVERAGE PASSED! All classes achieved ≥ ${threshold}% coverage.`);
console.log('================================================================================\n');
process.exit(0);
