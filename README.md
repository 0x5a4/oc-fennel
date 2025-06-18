# oc-fennel

The [fennel](https://fennel-lang.org/) programming language, packaged for OpenComputers.

## Installation

You can install the package vie `oppm`

```sh
oppm register 0x5a4/oc-fennel
```

and then install fennel with

```sh
oppm install fennel
```

This will install the `fennel` script you're used to and the fennel library. All of this combined will use about 300KB of disk space, so a tier 2 disk is propably recommended.

## Search Path

The fennel searcher, allowing you to `require` fennel code is installed by default. No need to call `require("fennel").install()`!

Fennel's search path is modified to resemble the default Lua one, with every occurence of `lib` replaced with `fnllib`.

In the list below, `?` represents the module being required.

### For normal modules

- `/fnllib/?.fnl`
- `/usr/fnllib/?.fnl`
- `/home/fnllib/?.fnl`
- `./?.fnl`
- `/fnllib/?/init.fnl`
- `/usr/fnllib/?/init.fnl`
- `/home/fnllib/?/init.fnl`
- `./?/init.fnl`

### For macros

- `/fnllib/?.fnl`
- `/usr/fnllib/?.fnl`
- `/home/fnllib/?.fnl`
- `./?.fnl`
- `/fnllib/?/init-macros.fnl`
- `/usr/fnllib/?/init-macros.fnl`
- `/home/fnllib/?/init-macros.fnl`
- `./?/init-macros.fnl`
- `/fnllib/?/init.fnl`
- `/usr/fnllib/?/init.fnl`
- `/home/fnllib/?/init.fnl`
- `./?/init.fnl`
