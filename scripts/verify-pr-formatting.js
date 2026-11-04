/**
 * scripts/verify-pr-formatting.js
 *
 * Verifies Prettier code formatting only on files modified in the PR delta.
 * Avoids blocking PRs due to legacy formatting in untouched files.
 */

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const args = process.argv.slice(2);
let deltaDir = "changed-sources/force-app";

for (let i = 0; i < args.length; i++) {
  if (args[i] === "--delta-dir" && args[i + 1]) deltaDir = args[++i];
}

const SUPPORTED_EXTENSIONS = new Set([
  ".js",
  ".html",
  ".css",
  ".cmp",
  ".component",
  ".json",
  ".md",
  ".yaml",
  ".yml"
]);

// If running in an environment with working Apex Prettier plugin (Linux / non-Windows), also check .cls
if (process.platform !== "win32") {
  SUPPORTED_EXTENSIONS.add(".cls");
  SUPPORTED_EXTENSIONS.add(".trigger");
}

const IGNORED_DIRS = new Set([
  "staticresources",
  "node_modules",
  ".git",
  ".sfdx",
  ".sf",
  "coverage"
]);

function findFiles(dir, fileList = []) {
  if (!fs.existsSync(dir)) return fileList;
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (IGNORED_DIRS.has(entry.name)) continue;
      findFiles(fullPath, fileList);
    } else {
      const ext = path.extname(entry.name);
      if (SUPPORTED_EXTENSIONS.has(ext) && !entry.name.endsWith("-meta.xml")) {
        fileList.push(fullPath);
      }
    }
  }
  return fileList;
}

console.log(
  "================================================================================"
);
console.log("🎨 PRETTIER CODE FORMATTING CHECK (CHANGED PR FILES)");
console.log(
  "================================================================================"
);

let filesToCheck = [];

if (fs.existsSync(deltaDir) || fs.existsSync("changed-sources")) {
  const searchDir = fs.existsSync(deltaDir) ? deltaDir : "changed-sources";
  filesToCheck = findFiles(searchDir);
} else {
  // If no delta directory exists (e.g. run locally), fallback to global check
  console.log(
    "ℹ️  No delta directory found; verifying all component and source files..."
  );
  const cmd =
    'npx prettier --list-different "**/*.{cmp,component,css,html,js,json,md,yaml,yml}"';
  const result = spawnSync(cmd, {
    stdio: "inherit",
    shell: true
  });
  process.exit(result.status || 0);
}

if (filesToCheck.length === 0) {
  console.log("ℹ️  No relevant source files were modified in this PR delta.");
  console.log("✅ Prettier formatting check passed.");
  console.log(
    "================================================================================\n"
  );
  process.exit(0);
}

// Map files back to workspace root paths if they exist
const mappedFiles = filesToCheck.map((f) => {
  const rel = path.relative(process.cwd(), f).replace(/\\/g, "/");
  if (rel.startsWith("changed-sources/force-app")) {
    const repoPath = rel.replace("changed-sources/", "");
    if (fs.existsSync(repoPath)) return repoPath;
  }
  return rel;
});

console.log(
  `Found ${mappedFiles.length} modified file(s) to verify for Prettier formatting:`
);
mappedFiles.forEach((f) => console.log(`   - ${f}`));
console.log("");

const result = spawnSync(
  "npx",
  ["prettier", "--list-different", ...mappedFiles],
  {
    stdio: "inherit",
    shell: process.platform === "win32"
  }
);

if (result.status !== 0) {
  console.log(
    "\n================================================================================"
  );
  console.log(
    "❌ BUILD FAILED: Prettier detected unformatted code in modified files."
  );
  console.log(
    "Please run 'npm run prettier' on your modified files before merging."
  );
  console.log(
    "================================================================================\n"
  );
  process.exit(result.status || 1);
}

console.log(
  "\n================================================================================"
);
console.log("✅ All modified files are properly formatted!");
console.log(
  "================================================================================\n"
);
process.exit(0);
