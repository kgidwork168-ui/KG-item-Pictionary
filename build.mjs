import { cp, mkdir, rm } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(".");
const dist = resolve(root, "dist");
const files = ["index.html", "styles.css", "app.js", "config.js"];

await rm(dist, { recursive: true, force: true });
await mkdir(dist, { recursive: true });
for (const file of files) await cp(resolve(root, file), resolve(dist, file));
await cp(resolve(root, ".nojekyll"), resolve(dist, ".nojekyll"));
console.log(`Built ${files.length + 1} files into dist/`);
