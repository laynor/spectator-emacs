# spectator-emacs

* [Homepage](https://github.com/laynor/spectator-emacs#readme)
* [Issues](https://github.com/laynor/spectator-emacs/issues)
* [Documentation](http://rubydoc.info/gems/spectator-emacs/frames)
* Email [mailto:laynor at gmail.com]

## Description

`spectator-emacs` is a [Spectator][spectator]
extension that provides discreet notificatoins in the Emacs modeline,
via the [Enotify][enotify] Emacs notification
system.

The RSpec output is displayed in an emacs buffer, and using the
[RSpec Org Formatter][RSpecOrgFormatter],
they are nicely formatted as an org-mode file. Minimize your switching
from Emacs to the shell or the browser to just display the test
results!

If you hate growl-style popups and prefer a simple green/red
(customizable!) indicator on the modeline, spectator-emacs is for you.

## Features

* Notifications on the emacs modeline
* Short summary report on mouse-over in the modeline indicator
* Easily switch to the results buffer with just a click on the
  modeline indicator
* Org formatted RSpec results with the aid of RSpec Org Formatter
* Summary extraction can be customized to work with different RSpec
  output formats
* all the features offered by Spectator

## Examples

To run `spectator-emacs`, just run it!
```
$ spectator-emacs
```
To customize it, just create a ruby script lik

## Requirements

`spectator-emacs` requires a working Emacs installation. You need to
install [Enotify][enotify], which can be found in the [MELPA][melpa]
repository.

You also need to load the `enotify-spectator-emacs` Enotify plugin.


## Install

```
$ gem install spectator-emacs
```

## Synopsis

```
$ spectator-emacs
```

## Copyright

Copyright (c) 2013 Alessandro Piras

See LICENSE.txt for details.

[enotify]:http://github.com/laynor/enotify
[spectator]:http://github.com/elia/spectator
[RSpecOrgFormatter]:http://github.org/laynor/rspec_org_formatter
[melpa]:http://melpa.milkbox.net/
