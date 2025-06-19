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

As a last step, reboot your computer to install the fennel searcher automatically.

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

## Writing programs in fennel

The default OpenOS Shell can only run lua programs, so we have to get our fennel to be called from lua. There are 2 ways to do this. Either compiling your script to lua, or creating a small wrapper that forwards the call.

Lets suppose we want to write a program `hello` in fennel.

### Wrapper

First copy your `hello.fnl` to `/fnlbin/hello.fnl`. Technically the path doesn't matter, we'll just have to specify an absolute one later.

Now create a file `/bin/hello.lua` and put the following line of code in there:

```lua
require("fennel").dofile("/fnlbin/hello.fnl", {}, ...)
```

### Compilation

This is done the usual fennel way. Run `fennel --compile hello.fnl > /usr/bin/hello.lua`.
