// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:build/build.dart';
import 'package:test/test.dart';

import 'package:build_config/build_config.dart';
import 'package:build_config/src/common.dart';
import 'package:build_config/src/expandos.dart';

void main() {
  test('build.yaml can be parsed', () {
    var buildConfig = BuildConfig.parse('example', ['a', 'b'], buildYaml);
    expectBuildTargets(buildConfig.buildTargets, {
      'example:a': createBuildTarget(
        'example',
        key: 'example:a',
        builders: {
          'b|b': TargetBuilderConfig(
              isEnabled: true, generateFor: InputSet(include: ['lib/a.dart'])),
          'c|c': TargetBuilderConfig(isEnabled: false),
          'example|h': TargetBuilderConfig(
              isEnabled: true, options: BuilderOptions({'foo': 'bar'})),
          'example|p': TargetBuilderConfig(
              isEnabled: true, options: BuilderOptions({'baz': 'zap'})),
        },
        // Expecting $default => example:example
        dependencies: ['example:example', 'b:b', 'c:d'],
        sources: InputSet(include: ['lib/a.dart', 'lib/src/a/**']),
      ),
      'example:example': createBuildTarget(
        'example',
        dependencies: ['f:f', 'example:a'],
        sources: InputSet(
            include: ['lib/e.dart', 'lib/src/e/**'],
            exclude: ['lib/src/e/g.dart']),
      )
    });
    expectBuilderDefinitions(buildConfig.builderDefinitions, {
      'example|h': createBuilderDefinition(
        'example',
        key: 'example|h',
        builderFactories: ['createBuilder'],
        autoApply: AutoApply.dependents,
        isOptional: true,
        buildTo: BuildTo.cache,
        import: 'package:example/e.dart',
        buildExtensions: {
          '.dart': [
            '.g.dart',
            '.json',
          ]
        },
        requiredInputs: ['.dart'],
        runsBefore: ['foo_builder|foo_builder'].toSet(),
        appliesBuilders: ['foo_builder|foo_builder'].toSet(),
        defaults: TargetBuilderConfigDefaults(
          generateFor: const InputSet(include: ['lib/**']),
          options: const BuilderOptions({'foo': 'bar'}),
          releaseOptions: const BuilderOptions({'baz': 'bop'}),
        ),
      ),
    });
    expectPostProcessBuilderDefinitions(
        buildConfig.postProcessBuilderDefinitions, {
      'example|p': createPostProcessBuilderDefinition(
        'example',
        key: 'example|p',
        builderFactory: 'createPostProcessBuilder',
        import: 'package:example/p.dart',
        defaults: TargetBuilderConfigDefaults(
          generateFor: const InputSet(include: ['web/**']),
          options: const BuilderOptions({'foo': 'bar'}),
          releaseOptions: const BuilderOptions({'baz': 'bop'}),
        ),
      ),
    });
    expectGlobalOptions(buildConfig.globalOptions, {
      'example|h':
          GlobalBuilderConfig(options: const BuilderOptions({'foo': 'global'})),
      'b|b': GlobalBuilderConfig(
          devOptions: const BuilderOptions({'foo': 'global_dev'}),
          releaseOptions: const BuilderOptions({'foo': 'global_release'}))
    });
  });

  test('build.yaml can omit a targets section', () {
    var buildConfig =
        BuildConfig.parse('example', ['a', 'b'], buildYamlNoTargets);
    expectBuildTargets(buildConfig.buildTargets, {
      'example:example': createBuildTarget(
        'example',
        dependencies: ['a:a', 'b:b'].toSet(),
        sources: InputSet(),
      ),
    });
    expectBuilderDefinitions(buildConfig.builderDefinitions, {
      'example|a': createBuilderDefinition(
        'example',
        key: 'example|a',
        builderFactories: ['createBuilder'],
        autoApply: AutoApply.none,
        isOptional: false,
        buildTo: BuildTo.cache,
        import: 'package:example/builder.dart',
        buildExtensions: {
          '.dart': [
            '.g.dart',
            '.json',
          ]
        },
        requiredInputs: const [],
        runsBefore: Set<String>(),
        appliesBuilders: Set<String>(),
      ),
    });
  });

  test('build.yaml can be empty', () {
    var buildConfig = BuildConfig.parse('example', ['a', 'b'], '');
    expectBuildTargets(buildConfig.buildTargets, {
      'example:example': createBuildTarget(
        'example',
        dependencies: ['a:a', 'b:b'].toSet(),
        sources: InputSet(),
      ),
    });
    expectBuilderDefinitions(buildConfig.builderDefinitions, {});
    expectPostProcessBuilderDefinitions(
        buildConfig.postProcessBuilderDefinitions, {});
  });
}

var buildYaml = r'''
global_options:
  "|h":
    options:
      foo: global
  b|b:
    dev_options:
      foo: global_dev
    release_options:
      foo: global_release
targets:
  a:
    builders:
      "|h":
        options:
          foo: bar
      "|p":
        options:
          baz: zap
      b|b:
        generate_for:
          - lib/a.dart
      c|c:
        enabled: false
    dependencies:
      - $default
      - b
      - c:d
    sources:
      - "lib/a.dart"
      - "lib/src/a/**"
  $default:
    dependencies:
      - f
      - :a
    sources:
      include:
        - "lib/e.dart"
        - "lib/src/e/**"
      exclude:
        - "lib/src/e/g.dart"
builders:
  h:
    builder_factories: ["createBuilder"]
    import: package:example/e.dart
    build_extensions: {".dart": [".g.dart", ".json"]}
    auto_apply: dependents
    required_inputs: [".dart"]
    runs_before: ["foo_builder"]
    applies_builders: ["foo_builder"]
    is_optional: True
    defaults:
      generate_for: ["lib/**"]
      options:
        foo: bar
      release_options:
        baz: bop
post_process_builders:
  p:
    builder_factory: "createPostProcessBuilder"
    import: package:example/p.dart
    defaults:
      generate_for: ["web/**"]
      options:
        foo: bar
      release_options:
        baz: bop
''';

var buildYamlNoTargets = '''
builders:
  a:
    builder_factories: ["createBuilder"]
    import: package:example/builder.dart
    build_extensions: {".dart": [".g.dart", ".json"]}
''';

void expectBuilderDefinitions(Map<String, BuilderDefinition> actual,
    Map<String, BuilderDefinition> expected) {
  expect(actual.keys, unorderedEquals(expected.keys));
  for (var p in actual.keys) {
    expect(actual[p], _matchesBuilderDefinition(expected[p]));
  }
}

void expectPostProcessBuilderDefinitions(
    Map<String, PostProcessBuilderDefinition> actual,
    Map<String, PostProcessBuilderDefinition> expected) {
  expect(actual.keys, unorderedEquals(expected.keys));
  for (var p in actual.keys) {
    expect(actual[p], _matchesPostProcessBuilderDefinition(expected[p]));
  }
}

void expectGlobalOptions(Map<String, GlobalBuilderConfig> actual,
    Map<String, GlobalBuilderConfig> expected) {
  expect(actual.keys, unorderedEquals(expected.keys));
  for (var p in actual.keys) {
    expect(actual[p], _matchesGlobalBuilderConfig(expected[p]));
  }
}

Matcher _matchesBuilderDefinition(BuilderDefinition definition) => TypeMatcher<
        BuilderDefinition>()
    .having((d) => d.builderFactories, 'builderFactories',
        definition.builderFactories)
    .having(
        (d) => d.buildExtensions, 'buildExtensions', definition.buildExtensions)
    .having(
        (d) => d.requiredInputs, 'requiredInputs', definition.requiredInputs)
    .having((d) => d.runsBefore, 'runsBefore', definition.runsBefore)
    .having(
        (d) => d.appliesBuilders, 'appliesBuilders', definition.appliesBuilders)
    .having((d) => d.defaults, 'defaults',
        _matchesBuilderConfigDefaults(definition.defaults))
    .having((d) => d.autoApply, 'autoApply', definition.autoApply)
    .having((d) => d.isOptional, 'isOptional', definition.isOptional)
    .having((d) => d.buildTo, 'buildTo', definition.buildTo)
    .having((d) => d.import, 'import', definition.import)
    .having((d) => d.key, 'key', definition.key)
    .having((d) => d.package, 'package', definition.package);

Matcher _matchesPostProcessBuilderDefinition(
        PostProcessBuilderDefinition definition) =>
    TypeMatcher<PostProcessBuilderDefinition>()
        .having((d) => d.builderFactory, 'builderFactory',
            definition.builderFactory)
        .having((d) => d.defaults, 'defaults',
            _matchesBuilderConfigDefaults(definition.defaults))
        .having((d) => d.import, 'import', definition.import)
        .having((d) => d.key, 'key', definition.key)
        .having((d) => d.package, 'package', definition.package);

Matcher _matchesGlobalBuilderConfig(GlobalBuilderConfig config) =>
    TypeMatcher<GlobalBuilderConfig>()
        .having(
            (c) => c.options.config, 'options.config', config.options.config)
        .having((c) => c.devOptions.config, 'devOptions.config',
            config.devOptions.config)
        .having((c) => c.releaseOptions.config, 'releaseOptions.config',
            config.releaseOptions.config);

Matcher _matchesBuilderConfigDefaults(TargetBuilderConfigDefaults defaults) =>
    TypeMatcher<TargetBuilderConfigDefaults>()
        .having((d) => d.generateFor.include, 'generateFor.include',
            defaults.generateFor.include)
        .having((d) => d.generateFor.exclude, 'generateFor.exclude',
            defaults.generateFor.exclude)
        .having(
            (d) => d.options.config, 'options.config', defaults.options.config)
        .having((d) => d.devOptions.config, 'devOptions.config',
            defaults.devOptions.config)
        .having((d) => d.releaseOptions.config, 'releaseOptions.config',
            defaults.releaseOptions.config);

void expectBuildTargets(
    Map<String, BuildTarget> actual, Map<String, BuildTarget> expected) {
  expect(actual.keys, unorderedEquals(expected.keys));
  for (var p in actual.keys) {
    expect(actual[p], _matchesBuildTarget(expected[p]));
  }
}

Matcher _matchesBuildTarget(BuildTarget target) => TypeMatcher<BuildTarget>()
    .having((t) => t.package, 'package', target.package)
    .having(
        (t) => t.builders, 'builders', _matchesBuilderConfigs(target.builders))
    .having((t) => t.dependencies, 'dependencies', target.dependencies)
    .having((t) => t.sources.include, 'sources.include', target.sources.include)
    .having(
        (t) => t.sources.exclude, 'sources.exclude', target.sources.exclude);

Matcher _matchesBuilderConfigs(Map<String, TargetBuilderConfig> configs) =>
    equals(configs.map((k, v) => MapEntry(k, _matchesBuilderConfig(v))));

Matcher _matchesBuilderConfig(TargetBuilderConfig expected) =>
    TypeMatcher<TargetBuilderConfig>()
        .having((c) => c.isEnabled, 'isEnabled', expected.isEnabled)
        .having(
            (c) => c.options.config, 'options.config', expected.options.config)
        .having((c) => c.devOptions.config, 'devOptions.config',
            expected.devOptions.config)
        .having((c) => c.releaseOptions.config, 'releaseOptions.config',
            expected.releaseOptions.config)
        .having((c) => c.generateFor?.include, 'generateFor.include',
            expected.generateFor?.include)
        .having((c) => c.generateFor?.exclude, 'generateFor.exclude',
            expected.generateFor?.exclude);

BuildTarget createBuildTarget(String package,
    {String key,
    Map<String, TargetBuilderConfig> builders,
    Iterable<String> dependencies,
    InputSet sources}) {
  return runInBuildConfigZone(() {
    var target = BuildTarget(
      builders: builders,
      dependencies: dependencies,
      sources: sources,
    );

    packageExpando[target] = package;
    builderKeyExpando[target] = key ?? '$package:$package';

    return target;
  }, package, []);
}

BuilderDefinition createBuilderDefinition(String package,
    {List<String> builderFactories,
    AutoApply autoApply,
    bool isOptional,
    BuildTo buildTo,
    String import,
    Map<String, List<String>> buildExtensions,
    String key,
    Iterable<String> requiredInputs,
    Iterable<String> runsBefore,
    Iterable<String> appliesBuilders,
    TargetBuilderConfigDefaults defaults}) {
  return runInBuildConfigZone(() {
    var definition = BuilderDefinition(
        builderFactories: builderFactories,
        autoApply: autoApply,
        isOptional: isOptional,
        buildTo: buildTo,
        import: import,
        buildExtensions: buildExtensions,
        requiredInputs: requiredInputs,
        runsBefore: runsBefore,
        appliesBuilders: appliesBuilders,
        defaults: defaults);
    packageExpando[definition] = package;
    builderKeyExpando[definition] = key ?? '$package:$package';
    return definition;
  }, package, []);
}

PostProcessBuilderDefinition createPostProcessBuilderDefinition(String package,
    {String builderFactory,
    String import,
    String key,
    TargetBuilderConfigDefaults defaults}) {
  return runInBuildConfigZone(() {
    var definition = PostProcessBuilderDefinition(
        builderFactory: builderFactory, import: import, defaults: defaults);
    packageExpando[definition] = package;
    builderKeyExpando[definition] = key ?? '$package:$package';
    return definition;
  }, package, []);
}
