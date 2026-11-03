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
const rawJsFiles = findJsFiles(searchDir);

if (rawJsFiles.length === 0) {
    console.log('ℹ️  No JavaScript (.js) files were modified in this PR delta.');
    console.log('✅ ESLint check passed (no files to inspect).');
    console.log('================================================================================\n');
    process.exit(0);
}

// Prefer files in repository workspace root (force-app/...) if available
const jsFiles = rawJsFiles.map(f => {
    const rel = path.relative(process.cwd(), f).replace(/\\/g, '/');
    if (rel.startsWith('changed-sources/force-app')) {
        const repoPath = rel.replace('changed-sources/', '');
        if (fs.existsSync(repoPath)) return repoPath;
    }
    return rel;
});

console.log(`Found ${jsFiles.length} modified JavaScript file(s) to inspect:`);
jsFiles.forEach(f => console.log(`   - ${f}`));
console.log('');

const eslintArgs = [];
if (fs.existsSync('.eslintrc.json')) {
    eslintArgs.push('-c', '.eslintrc.json');
}
eslintArgs.push(...jsFiles);

const result = spawnSync('npx', ['eslint', ...eslintArgs], {
    stdio: 'inherit',
    shell: process.platform === 'win32'
});

if (result.status !== 0) {
    console.log('\n================================================================================');
    console.log('❌ BUILD FAILED: ESLint reported errors on modified JavaScript files.');
    console.log('Please fix the JavaScript errors above before merging.');
    console.log('================================================================================\n');
    process.exit(result.status || 1);
}

console.log('\n================================================================================');
console.log('✅ ESLint passed on all modified JavaScript files!');
console.log('================================================================================\n');
process.exit(0);
