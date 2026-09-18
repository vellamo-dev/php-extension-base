# What this project is

This project is a starter kit. It turns ordinary PHP code into a small native add-on file that PHP can load.

You write code in a familiar PHP style. A compiler called [TypePHP](https://github.com/swoole/typephp) translates that code into a fast native library. The result is one file you can ship with an application.

**Why bother**

- The add-on starts faster and uses less memory than the same logic running as loose PHP files.
- The compiled file is harder to read than source code, which helps if you sell or protect business logic.
- The same project can produce a Mac version and a Linux version from one codebase.
- Tests check that the add-on actually loads and that a sample script still runs.

You do not need to understand compilers. You need a Mac, a few install steps, and the commands below.

---

## What you get after a build

On a Mac:

- `target/build/targets/macos/` — the Mac add-on file

On Linux (built from a Mac, see below):

- `target/build/targets/linux/` — the Linux add-on file plus a few helper libraries it needs

The add-on name comes from `project.yml` (`name:`). PHP will list it as `typephp_` plus that name. Example: name `core_extension` loads as `typephp_core_extension`.

---

## Before you start (Mac)

1. Use a Mac with Apple silicon.
2. Install Homebrew if you do not have it: https://brew.sh
3. You need PHP 8.4 or 8.5, plus build tools. The setup script can install missing pieces through Homebrew.
4. Open Terminal and go to this project folder.

If a script says “permission denied”, run this once:

```shell
./tools/share/fix-permissions.sh
```

---

## Mac: first-time setup

Do this once on a new machine (or when you switch PHP version).

**Step 1 — pick PHP**

```shell
./tools/share/php-mac.sh
```

The script lists PHP copies on your Mac. Type the number you want. It stores the choice in `project-php-mac.conf` and writes the version into `project.yml`.

If PHP is missing, it offers to install it with Homebrew. If Homebrew is missing, it tells you how to install Homebrew.

**Step 2 — install the compiler**

```shell
./tools/share/setup-type-php.sh
```

This downloads TypePHP and builds its helper library for the PHP you picked.
If you later pick a different PHP, run:

```shellell
./tools/share/rebuild-phpx.sh
```

---

## Mac: build and check

**Step 3 — build**

```shellell
./tools/build/targets/macos/build.sh
```

This compiles everything under `src/main` into the Mac add-on.

**Step 4 — check that PHP can load it**

```shellell
./tools/test/targets/macos/test-load.sh
```

You want:

```
Testing: target/build/targets/macos/core_extension.so
Loaded: Success
Loaded As: typephp_core_extension
Testing constant: CORE_BASE_VERSIONS
Value of constant: 1.0.0
```

If it says the constant is missing, build again (step 3) after you change `src/main/functions.php`.

**Step 5 — run the sample script**

```shell
./tools/test/targets/macos/test-php.sh
```

This runs `src/tests/test.php` with the add-on loaded. You want `Result: Success`.

---

## Linux add-on, built from a Mac

You can make a Linux add-on without a Linux PC. The Mac starts a small official Linux box (Apple “container”) and builds inside it.

**One extra install:** Apple Container
https://github.com/apple/container/releases
Install the signed package, then run `container system start`.

PHP version is taken from `project.yml`. Nothing asks you for a version.

```shell
./tools/build/targets/linux/build-from-macos.sh
```

The first run may download a Linux image. Later runs reuse it. If you change `php-version` in `project.yml`, a new image is built automatically.

Check the Linux add-on:

```shell
./tools/build/targets/linux/test-load-from-macos.sh
./tools/build/targets/linux/test-php-from-macos.sh
```

You want the same kind of Success lines as on Mac. The Linux folder will contain the add-on plus four helper files (`libphpx`, `libgmp`, `libgmpxx`, `libmpfr`). Those files must travel together.

---

## Linux computer (not a Mac)

Building directly on a Linux machine is not written yet.

---

## Windows

Not planned. If you need Windows, you would add your own scripts under `tools/build/targets/windows`.

---

## How to start your own product from this kit

1. Copy this whole folder.
2. Open `project.yml` and change `name` (and `php-version` if you must).
3. Put your code in `src/main`.
4. Put checks in `src/tests/test.php`.
5. Keep at least one `const SOMETHING = '...';` in `src/main/functions.php` so the load test has something to read.
6. Run the Mac steps above.

Do not mix Mac output with Linux output. Each stays in its own folder under `target/build/targets/`.
