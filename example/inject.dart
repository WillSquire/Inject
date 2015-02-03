// Copyright (c) 2015, Will Squire. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library inject.example;

import 'package:inject_module/inject_module.dart';
import 'dart:convert';
import 'dart:io';

main() {
  exampleOne();
  exampleTwo();
  exampleThree();
}

class User {
  // Example class. Passing this class as an inject data map
  // will mean 'name' and 'age' are the triggers, and their
  // values are what will be injected upon triggering.
  String name = 'Will Squire';
  int age = 25;
}

exampleOne() {
  // Specify the location of the file Inject will analyse
  // and process.
  Uri uri = new Uri.file('../LICENSE');

  // Define either an Object or a Map to use as Inject's data
  // map. Inject uses the data maps' keys/variable names as
  // the triggers to replace/inject data. Once a trigger is
  // found in the source file's data, its replaced with the
  // data maps' corresponding value for the trigger.
  User user = new User();

  // Inject requires at least two arguments, one is the source
  // file and the other is the data map. Inject can also take
  // another two optional parameters, a prefix and then a suffix.
  // Using a prefix or both a prefix and suffix (circumfix)
  // means inject triggers need these additional significations
  // before triggers can be detected in the data. If using an
  // object as the data map, call fromObject constructor.
  InjectModule injectModule = new InjectModule.fromObject(uri, user);

  // Inject can now analyse and transform the given file
  // data, returning the output as a stream.
  injectModule.process()
  .transform(UTF8.decoder)
  .listen((String char) {
    // Do something with the compiled result.
    print(char);
  });
}

exampleTwo() {
  // Defining the dataMap as a map type. In this data map the
  // trigger 'body' in will inject the content of a file as a
  // stream. Thus, injecting one stream into another.
  Map<String,Object> dataMap = {
    'body' : new File(new Uri.file('../README.md').toFilePath()).openRead()
  };

  // A third parameters has been passed here, which means
  // triggers will need the prefix of '$' to be recognised, and
  // have the corresponding value 'injected' in its place.
  // (Note, because Dart uses '$' for string interpolation,
  // it has been escaped with a '\').
  InjectModule injectModule = new InjectModule(new Uri.file('../LICENSE'), dataMap, '\$');

  // Process
  injectModule.process()
  .transform(UTF8.decoder)
  .listen((String char) {
    // Result.
    print(char);
  });
}

exampleThree() {
  // The third and forth parameters have been passed for each
  // Inject module here, which means triggers will need the
  // prefix of '<!--' and suffix of '-->' to be recognised, to
  // have the corresponding value 'injected' in its place.
  // Notice that HTML comment syntax was used for this. This
  // is so the files can be used even without Inject processing
  // the trigger, as it will not show up on the client's
  // machine.
  String prefix = '<!--';
  String suffix = '-->';

  Map<String,Object> headerDataMap = {
    'title' : "Website title"
  };

  Map<String,Object> footerDataMap = {
    'contactNumber' : "0800-Etc"
  };

  // In this data map, the values given are other Inject modules.
  // This takes the output from those streams and injects them
  // at the given location when this stream is processed.
  Map<String,Object> dataMap = {
    'header' : new InjectModule(new Uri.file('../LICENSE'), headerDataMap, prefix, suffix),
    'footer' : new InjectModule(new Uri.file('../LICENSE'), footerDataMap, prefix, suffix)
  };

  InjectModule injectModule = new InjectModule(new Uri.file('../LICENSE'), dataMap, prefix, suffix);

  // Process
  injectModule.process()
  .transform(UTF8.decoder)
  .listen((String char) {
    // Result.
    print(char);
  });
}