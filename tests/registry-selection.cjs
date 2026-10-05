// Isolated platform selection harness: execute installed registry functions,
// simulate IPC/config persistence and record entrypoint bytes without QML execution.
const fs = require('node:fs');
const vm = require('node:vm');
const cp = require('node:child_process');
const {fileURLToPath, pathToFileURL} = require('node:url');
const [fixture, platform, operation, id] = process.argv.slice(2);
const registryText = fs.readFileSync(`${platform}/shell/services/PluginRegistry.qml`, 'utf8');
const functions = [...registryText.matchAll(/^  function \w+\([^\n]*\) \{\n[\s\S]*?^  \}/gm)].map(m => m[0]).join('\n');
const configPath = `${process.env.HOME}/.config/omarchy/shell.json`;
let config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const statePath = `${fixture}/registry.json`;
const context = {
  console: {warn() {}},
  Util: {
    isPlainObject: value => value !== null && typeof value === 'object' && !Array.isArray(value),
    canonicalWidgetId: value => value,
    cloneJson: value => JSON.parse(JSON.stringify(value)),
    fileUrl: value => pathToFileURL(value).href
  },
  installedPlugins: fs.existsSync(statePath) ? JSON.parse(fs.readFileSync(statePath, 'utf8')) : {},
  registryRevision: 0, scanning: false, lastEnableError: '',
  firstPartyDir: `${platform}/shell/plugins`, pluginsDir: `${process.env.HOME}/.config/omarchy/plugins`,
  scanProcess: {}, pluginsChanged() {}, scanFinished() {},
  shellConfigProvider: () => config,
  shellConfigMutator: fn => { fn(config); fs.writeFileSync(configPath, JSON.stringify(config)); }
};
context.registry = context;
vm.createContext(context);
vm.runInContext(functions, context, {filename: 'installed-PluginRegistry-functions.js'});
function rescan() {
  context.rescan();
  const result = cp.spawnSync(context.scanProcess.command[0], context.scanProcess.command.slice(1), {encoding:'utf8'});
  if (result.status !== 0) throw new Error(result.stderr);
  context.parseScanOutput(result.stdout);
  fs.writeFileSync(statePath, JSON.stringify(context.installedPlugins));
}
if (operation === 'rescan') {
  if (fs.existsSync(`${fixture}/inject-shadow`)) {
    const path = `${context.pluginsDir}/zz-shadow`;
    fs.mkdirSync(path, {recursive:true});
    fs.copyFileSync(`${fixture}/source/manifest.json`, `${path}/manifest.json`);
    fs.writeFileSync(`${path}/Fixture.qml`, 'UNREVIEWED SHADOW\n');
    fs.unlinkSync(`${fixture}/inject-shadow`);
  }
  if (fs.existsSync(`${fixture}/inject-casefold`)) {
    const path = `${context.pluginsDir}/test.pinned`;
    cp.execFileSync(process.env.REAL_GIT, ['-C', path, 'config', 'core.ignorecase', 'true']);
    fs.writeFileSync(`${path}/extra.qml`, 'UNREVIEWED CASEFOLD\n');
    fs.unlinkSync(`${fixture}/inject-casefold`);
  }
  rescan();
} else {
  if (!fs.existsSync(statePath)) rescan();
  if (operation === 'source') {
    const manifest = context.installedPlugins[id];
    console.log(JSON.stringify({ok:!!manifest, scanning:context.scanning, sourceDir:manifest?.__sourceDir || '', firstParty:!!manifest?.__isFirstParty}));
  } else if (operation === 'list') {
    // Run shell.qml's actual list renderer against the actual registry map.
    const shellText = fs.readFileSync(`${platform}/shell/shell.qml`, 'utf8');
    const renderer = shellText.match(/^    function listPlugins\(\): string \{\n[\s\S]*?^    \}/m);
    if (!renderer) throw new Error('Installed shell listPlugins function missing');
    context.shell = {pluginRegistry:context, isActiveBarOption:()=>false};
    vm.runInContext(renderer[0].replace('(): string', '()') + '\nlistPlugins()', context);
    console.log(vm.runInContext('listPlugins()', context));
  } else if (operation === 'enable' || operation === 'disable') {
    if (!context.setEnabled(id, operation === 'enable', {})) throw new Error('Registry refused activation');
    if (operation === 'enable') {
      const manifest = context.installedPlugins[id];
      const url = context.entryPointUrl(manifest, manifest.kinds[0]);
      if (url) fs.appendFileSync(`${fixture}/enabled-content`, fs.readFileSync(fileURLToPath(url)));
    }
    fs.writeFileSync(`${fixture}/enabled.json`, JSON.stringify(Object.keys(context.installedPlugins).filter(key => context.isEnabled(key) && !context.installedPlugins[key].__isFirstParty)));
    console.log('ok');
  } else throw new Error(`Unknown operation ${operation}`);
}
