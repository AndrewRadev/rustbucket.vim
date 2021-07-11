## Usage

**TODO**

A collection of Rust tools for Vim that doesn't use fancy LSP stuff, but aims to produce 90%-useful stuff quickly.

You should be able to use the `gf` family of mappings on local imports (highlighting updates on write), like so:

![gf on imports](http://i.andrewradev.com/664ca4e2d0d797f3120064a30a1cb6ea.gif)

You can also try:

``` vim
:Info " Get a (Vim8) popup with detected info for the symbol under the cursor
:Doc  " Open up a browser with the documentation for the symbol under the cursor
```

For better results, use [Universal ctags](https://ctags.io/) and generate them for local crates, too (with [`cargo local`](https://github.com/AndrewRadev/cargo-local#cargo-tags) for instance).

For std info, install Rust std source code with rustup:

```
rustup component add rust-src
```

Generate tags for std:

``` vim
:RustbucketGenerateTags
```

But probably don't use it for now, I guess.

## Contributing

Pull requests are welcome, but take a look at [CONTRIBUTING.md](https://github.com/AndrewRadev/rustbucket.vim/blob/master/CONTRIBUTING.md) first for some guidelines. Be sure to abide by the [CODE_OF_CONDUCT.md](https://github.com/AndrewRadev/rustbucket.vim/blob/master/CODE_OF_CONDUCT.md) as well.
