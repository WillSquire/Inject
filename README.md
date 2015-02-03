# Inject

Inject is a form of pre-processor that replaces/'injects' data from a file
in accordance to data defined in a data map. Inject separates logic 
from the file being read, and because of this, Inject has a variable 
syntax that can adapt to different syntax conventions depending on 
the information it's being used on.

Inject reads the contents of files and maps/replaces data matching the 
specified key/value data specified in the data map. In a nutshell, 
Inject takes any file and turns it into an 'inject' module, where 
the data, the syntax scanned for and the dependencies themselves 
are given externally via dependency injection to Inject so it is 
not specified within the file. The data can then be 'interpreted' 
via the syntax that Inject has been told to use.

## Features

In most programming languages, symbols are used to prefix data (such 
as the '@mixin' syntax) or circumfix data (using a prefix and suffix, 
such as the double curly brace '{{mustache}}' syntax) to 'flag' a 
particular need for processing to be applied to information. However, 
not all do, and the available types of syntax obviously change 
depending on language. With Inject, a prefix or a prefix and suffix 
can be set, but if non are set, it will also work without additional 
flagging on the data, and find the raw triggers in the file (currently 
only a prefix or circumfix can be added to Inject's evaluation; the 
suffix alone is not due to its lack of usage).

The next important feature of Inject is that it's infrastructure has 
been built purely on the use of data streams. By using data streams, 
content can be received before the data from the source had even 
completed processing the entire content. As such, Inject returns a 
stream rather than 'complete' data, but thanks to Dart, the complete 
data can be returned with the use of casting a future from a stream 
if so desired.

Finally, Inject modules have been built to stack on-top of one 
another. For example, if an Inject object is passed as another Inject 
object's data map value, once this value is triggered, the processed 
output from it is injected into the original Inject object's data 
stream. The primary focus for Inject is that it is as modular as 
possible throughout, as such, think of Inject objects as building
blocks that can be stacked on-top of one another and reused due to 
a dependency injected approach. Inject does not require any of the 
files it is used with to have a particular extension, which means a 
HTML file can stay as a .html file, so it can be used as an Inject 
module, or on its own
 
## Usage

Inject can be used to further separate data from logic/processing. 
In an MVC framework for example, Inject can be used as a templating 
engine to keep Views more modular and separate from files that it 
'could' depend on or be used with by specifying this in the injection 
(via a Controller for example), rather than the file itself. This 
makes it less restrictive as to what it can be used with, or what 
additional files it requires, rather than those that 'hard-code' 
dependencies in the file itself.

This first example is the more long and drawn out illustration of 
usage, but this should hopefully articulate it's working better. 
It's taking a class as the data map, thus the fromObject() constructor
is needed.

```dart

import 'package:inject_module/inject_module.dart';
import 'dart:convert';

class User {
  // Example class. Passing this class as an inject data map
  // will mean 'name' and 'age' are the triggers, and their
  // values are what will be injected upon triggering.
  String name = 'Will Squire';
  int age = 25;
}

main() {
  // Specify the location of the file Inject will analyse
  // and process.
  File file = new File('../user_view.html');

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
  InjectModule injectModule = new InjectModule.fromObject(file, user);

  // Inject can now analyse and transform the given file
  // data, returning the output as a stream.
  injectModule.process()
  .transform(UTF8.decoder)
  .listen((String char) {
    // Do something with the compiled result.
    print(char);
  });
}

```

This next example takes a Map as the data map and injects a 
Stream as the replacement data.

```dart

import 'package:inject_module/inject_module.dart';
import 'dart:convert';
import 'dart:io';

main() {
  // Defining the dataMap as a map type. In this data map the
  // trigger 'body' in will inject the content of a file as a
  // stream. Thus, injecting one stream into another.
  Map<String,Object> dataMap = {
    'body' : new File(new Uri.file('../body.html').toFilePath()).openRead()
  };

  // A third parameters has been passed here, which means
  // triggers will need the prefix of '$' to be recognised, and
  // have the corresponding value 'injected' in its place.
  // (Note, because Dart uses '$' for string interpolation,
  // it has been escaped with a '\').
  InjectModule injectModule = new InjectModule(new File('../base.html'), dataMap, '\$');

  // Process
  injectModule.process()
  .transform(UTF8.decoder)
  .listen((String char) {
    // Result.
    print(char);
  });
}

```

This third and final example of usage presents the stacking 
ability that Inject modules can have on one another. Inject
streams can also inject another Inject stream.

```dart

import 'package:inject_module/inject_module.dart';
import 'dart:convert';

main() {
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
    'header' : new InjectModule(new File('../header.html'), headerDataMap, prefix, suffix),
    'footer' : new InjectModule(new File('../footer.html'), footerDataMap, prefix, suffix)
  };

  InjectModule injectModule = new InjectModule(new File('../base.html'), dataMap, prefix, suffix);

  // Process
  injectModule.process()
  .transform(UTF8.decoder)
  .listen((String char) {
    // Result.
    print(char);
  });
}

```

## Features and bugs

Please email myself feature requests and bugs, or find me on 
[twitter][Twitter]. It's lovely to hear any kind of feedback, so
feel free to contact me whenever.

[Twitter]: https://twitter.com/WillSquire