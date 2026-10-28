/**
 * scripts/run-pmd.js
 * 
 * Runs PMD code analysis on changed Apex files in the PR delta.
 */

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const args = process.argv.slice(2);
let deltaDir = 'changed-sources/force-app';
let pmdBin = process.env.PMD_BIN || 'pmd';

for (let i = 0; i < args.length; i++) {
    if (args[i] === '--delta-dir' && args[i + 1]) deltaDir = args[++i];
    if (args[i] === '--pmd-bin' && args[i + 1]) pmdBin = args[++i];
}

function findClsFiles(dir, fileList = []) {
    if (!fs.existsSync(dir)) return fileList;
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            findClsFiles(fullPath, fileList);
        } else if (entry.name.endsWith('.cls')) {
            fileList.push(fullPath);
        }
    }
    return fileList;
}

console.log('================================================================================');
console.log('🔍 PMD APEX CODE ANALYSIS');
console.log('================================================================================');

const searchDir = fs.existsSync(deltaDir) ? deltaDir : 'changed-sources';
const clsFiles = findClsFiles(searchDir);

if (clsFiles.length === 0) {
    console.log('ℹ️  No Apex (.cls) files were modified in this PR delta.');
    console.log('✅ PMD check passed (no files to inspect).');
    console.log('================================================================================\n');
    process.exit(0);
}

console.log(`Found ${clsFiles.length} modified Apex file(s) to analyze:`);
clsFiles.forEach(f => console.log(`   - ${path.relative(process.cwd(), f)}`));

const rulesetPath = path.join(process.cwd(), 'pmd', 'ruleset.xml');
console.log(`Ruleset: ${rulesetPath}\n`);

// Run PMD on the search directory
// PMD CLI supports: check -d <dir> -R <ruleset> -f text --minimum-priority 3
const pmdArgs = [
    'check',
    '-d', searchDir,
    '-R', rulesetPath,
    '-f', 'textcolor',
    '--minimum-priority', '3'
];

console.log(`Executing: ${pmdBin} ${pmdArgs.join(' ')}\n`);

const result = spawnSync(pmdBin, pmdArgs, {
    stdio: 'inherit',
    shell: true
});

if (result.status !== 0) {
    console.log('\n================================================================================');
    console.log('❌ BUILD FAILED: PMD detected code quality or security violations in Apex code.');
    console.log('Please resolve the reported PMD violations above before merging.');
    console.log('================================================================================\n');
    process.exit(result.status || 1);
}

console.log('\n================================================================================');
console.log('✅ PMD code analysis passed with 0 violations!');
console.log('================================================================================\n');
process.exit(0);
