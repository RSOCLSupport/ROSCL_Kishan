/**
 * scripts/lint-pr-files.js
 * 
 * Lints only JavaScript files modified/added in the current PR delta.
 * Avoids blocking PRs due to legacy issues in unrelated files.
 */

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const args = process.argv.slice(2);
let deltaDir = 'changed-sources/force-app';

for (let i = 0; i < args.length; i++) {
    if (args[i] === '--delta-dir' && args[i + 1]) deltaDir = args[++i];
}

function findJsFiles(dir, fileList = []) {
    if (!fs.existsSync(dir)) return fileList;
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            findJsFiles(fullPath, fileList);
        } else if (entry.name.endsWith('.js') && !entry.name.endsWith('.test.js')) {
            fileList.push(fullPath);
        }
    }
    return fileList;
}

console.log('================================================================================');
console.log('🔍 ESLINT CODE QUALITY CHECK (CHANGED LWC / AURA JAVASCRIPT FILES)');
console.log('================================================================================');

const searchDir = fs.existsSync(deltaDir) ? deltaDir : 'changed-sources';
const jsFiles = findJsFiles(searchDir);

if (jsFiles.length === 0) {
    console.log('ℹ️  No JavaScript (.js) files were modified in this PR delta.');
    console.log('✅ ESLint check passed (no files to inspect).');
    console.log('================================================================================\n');
    process.exit(0);
}

console.log(`Found ${jsFiles.length} modified JavaScript file(s) to inspect:`);
jsFiles.forEach(f => console.log(`   - ${path.relative(process.cwd(), f)}`));
console.log('');

// Run eslint using npx
const eslintArgs = [...jsFiles];
const result = spawnSync('npx', ['eslint', ...eslintArgs], {
    stdio: 'inherit',
    shell: true
});

if (result.status !== 0) {
    console.log('\n================================================================================');
    console.log('❌ BUILD FAILED: ESLint reported errors on modified JavaScript files.');
    console.log('================================================================================\n');
    process.exit(result.status || 1);
}

console.log('\n================================================================================');
console.log('✅ ESLint passed on all modified JavaScript files!');
console.log('================================================================================\n');
process.exit(0);
