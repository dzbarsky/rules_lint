import childProcess from 'child_process';
import path from 'path';
import fs from 'fs';
import os from 'os';

const node = process.argv[0];
const wrapper = process.argv[1];
const args = process.argv.slice(2);

const files = args.filter(arg => !arg.startsWith("-"));
const nonFiles = args.filter(arg => arg.startsWith("-"));

const tmpDirPath = fs.mkdtempSync("/tmp/");

const tmpFiles = [];
for (const f of files) {
    const destF = path.join(tmpDirPath, f);
    fs.mkdirSync(path.dirname(destF), {recursive: true});
    fs.cpSync(f, destF);
    fs.chmodSync(destF, "600");
    tmpFiles.push(destF);
}

const linterPath = path.join(process.env["RUNFILES"], process.env["ESLINT_PATH"]);
childProcess.spawnSync(linterPath, [...nonFiles, ...tmpFiles], {
    stdio: "inherit",
});

const diffOut = fs.createWriteStream(process.env["DIFF_PATH"]);

for (let i = 0; i < files.length; i++) {
    const origF = files[i];
    const newF = tmpFiles[i];
    const results = childProcess.spawnSync("diff", ["-U8", origF, newF], {
        encoding: 'utf8',
    });
    diffOut.write(results.stdout);
    if (results.error) {
        console.error(results.error);
    }
}

diffOut.close();

// HAX - for some reason the underlying binary doesn't create the files properly.
// I think the paths are wrong because it's running from runfiles.
fs.writeFileSync("simple/ts.eslint-report.txt", '');
