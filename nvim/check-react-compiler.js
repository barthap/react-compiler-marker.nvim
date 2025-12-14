#!/usr/bin/env node

const babel = require('@babel/core');
const parser = require('@babel/parser');
const fs = require('fs');
const path = require('path');

// Get command line arguments
const args = process.argv.slice(2);
const babelPluginPath = args[0] || 'node_modules/babel-plugin-react-compiler';
const filename = args[1] || 'stdin.tsx';

let BabelPluginReactCompiler;

// Try to load babel-plugin-react-compiler
try {
  BabelPluginReactCompiler = require(path.resolve(babelPluginPath));
} catch (e) {
  try {
    BabelPluginReactCompiler = require('babel-plugin-react-compiler');
  } catch (e2) {
    console.error(JSON.stringify({
      error: `Could not load babel-plugin-react-compiler: ${e2.message}`
    }));
    process.exit(1);
  }
}

const successfulCompilations = [];
const failedCompilations = [];

const logger = {
  logEvent(filename, rawEvent) {
    const event = { ...rawEvent, filename };
    switch (event.kind) {
      case 'CompileSuccess':
        successfulCompilations.push(event);
        break;
      case 'CompileError':
      case 'CompileDiagnostic':
      case 'PipelineError':
        failedCompilations.push(event);
        break;
    }
  }
};

const compilerOptions = {
  noEmit: true,
  compilationMode: 'infer',
  panicThreshold: 'none',
  environment: {
    enableTreatRefLikeIdentifiersAsRefs: true
  },
  logger
};

// Read code from stdin
let code = '';
process.stdin.setEncoding('utf8');
process.stdin.on('readable', () => {
  const chunk = process.stdin.read();
  if (chunk !== null) {
    code += chunk;
  }
});

process.stdin.on('end', () => {
  try {
    const ast = parser.parse(code, {
      sourceFilename: filename,
      plugins: ['typescript', 'jsx'],
      sourceType: 'module'
    });

    babel.transformFromAstSync(ast, code, {
      filename: filename,
      plugins: [[BabelPluginReactCompiler, compilerOptions]],
      configFile: false,
      babelrc: false
    });

    console.log(JSON.stringify({
      successfulCompilations,
      failedCompilations
    }));
  } catch (error) {
    console.error(JSON.stringify({
      error: error.message
    }));
    process.exit(1);
  }
});