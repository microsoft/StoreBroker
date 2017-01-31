# StoreBroker PowerShell Module
## Contributing

Looking to help out?  You've come to the right place.  We'd love your help in making this the best
submission solution for every Windows developer.

Looking for information on how to use this module?  Head on over to [README.md](README.md).

----------
#### Table of Contents

*   [Overview](#overview)
*   [Maintainers](#maintainers)
*   [Feedback](#feedback)
    *   [Bugs](#bugs)
    *   [Suggestions](#suggestions)
    *   [Questions](#questions)
*   [Static Analysis](#static-analysis)
*   [Visual Studio](#visual-studio)
*   [Module Manifest](#module-manifest)
*   [Logging](#logging)
*   [PowerShell Version](#powershell-version)
*   [Coding Guidelines](#coding-guidelines)
*   [Code Comments](#code-comments)
*   [Testing](#testing)
*   [Releasing](#releasing)
*   [Legal and Licensing](#legal-and-licensing)

----------

## Overview

We're excited that _you're_ excited about this project, and would welcome your contributions to help
it grow.  There are many different ways that you can contribute:

 1. Submit a [bug report](#bugs).
 2. Verify existing fixes for bugs.
 3. Submit your own fixes for a bug. Before submitting, please make sure you have:
   * Performed code reviews of your own
   * Updated the [test cases](#testing) if needed
   * Run the [test cases](#testing) to ensure no feature breaks or test breaks
   * Added the [test cases](#testing) for new code
   * Ensured that the code is free of [static analysis](#static-analysis) issues
 4. Submit a feature request.
 5. Help answer [questions](https://github.com/Microsoft/StoreBroker/issues?utf8=%E2%9C%93&q=is%3Aissue%20is%3Aopen%20label%3Aquestion).
 6. Write new [test cases](#testing).
 7. Tell others about the project.
 8. Tell the developers how much you appreciate the product!

You might also read these two blog posts about contributing code:
 * [Open Source Contribution Etiquette](http://tirania.org/blog/archive/2010/Dec-31.html) by Miguel de Icaza
 * [Don't "Push" Your Pull Requests](http://www.igvita.com/2011/12/19/dont-push-your-pull-requests/) by Ilya Grigorik.

Before submitting a feature or substantial code contribution, please discuss it with the
StoreBroker team via [Issues](https://github.com/Microsoft/StoreBroker/issues), and ensure it
follows the product roadmap. Note that all code submissions will be rigorously reviewed by the
StoreBroker Team. Only those that meet a high bar for both quality and roadmap fit will be merged
into the source.

## Maintainers

StoreBroker is maintained by:

- **[@HowardWolosky-MSFT](http://github.com/HowardWolosky-MSFT)**
- **[@DanBelcher-MSFT](http://github.com/DanBelcher-MSFT)**

As StoreBroker is a production dependency for Microsoft, we have a couple workflow restrictions:

- Anyone with commit rights can merge Pull Requests provided that there is a :+1: from one of
  the members above.
- Releases are performed by a member above so that we can ensure Microsoft internal processes
  remain up to date with the latest and that there are no regressions.

## Feedback

All issue types are tracked on the project's [Issues]( https://github.com/Microsoft/StoreBroker/issues)
page.

In all cases, make sure to search the list of issues before opening a new one.
Duplicate issues will be closed.

### Bugs

For a great primer on how to submit a great bug report, we recommend that you read:
[Painless Bug Tracking](http://www.joelonsoftware.com/articles/fog0000000029.html).

To report a bug, please include as much information as possible, namely:

* The version of the module (located in `StoreBroker\StoreBroker.psd1`)
* Your OS version
* Your version of PowerShell (`$PSVersionTable.PSVersion`)
* As much information as possible to reproduce the problem.
* If possible, logs from your execution of the task that exhibit the erroneous behavior
* The behavior you expect to see

Please also mark your issue with the 'bug' label.

### Suggestions

We welcome your suggestions for enhancements to the extension.
To ensure that we can integrate your suggestions effectively, try to be as detailed as possible
and include:

* What you want to achieve / what is the problem that you want to address.
* What is your approach for solving the problem.
* If applicable, a user scenario of the feature / enhancement in action.

Please also mark your issue with the 'suggestion' label.

### Questions

If you've read through all of the documentation, checked the Wiki, and the PowerShell help for
the command you're using still isn't enough, then please open an issue with the `question`
label and include:

* What you want to achieve / what is the problem that you want to address.
* What have you tried so far.

----------

## Static Analysis

This project leverages the [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer/)
PowerShell module for static analysis.

It is expected that this module shall remain "clean" from the perspective of that module.

To run the module, from the root of your enlistment simply call

        Invoke-ScriptAnalyzer -Path .\ -Recurse

That should return with no output.  If you see any output when calling that command,
either fix the issues that it calls out, or add a `[Diagnostics.CodeAnalysis.SuppressMessageAttribute()]`
with a justification explaining why it's ok to suppress that rule within that part of the script.
Refer to the [PSScriptAnalyzer documentation](https://github.com/PowerShell/PSScriptAnalyzer/) for
more information on how to use that attribute, or look at other existing examples within this module.

> Please ensure that your installation of PSScriptAnalyzer is up-to-date by running:
> `Update-Module -Name PSScriptAnalyzer`
> You should close and re-open your console window if the module was updated as a result of running
> that command.

----------

### Visual Studio

A Visual Studio project exists for this module:

    StoreBroker.pssproj

Even if **you** don't use Visual Studio to edit this module, others do, so if you
add new files to the module, be sure that the VS project is updated as well.

> To open this project in Visual Studio, you need to have the free
> [PowerShell Tools For Visual Studio](https://visualstudiogallery.msdn.microsoft.com/c9eb3ba8-0c59-4944-9a62-6eee37294597)
> extension installed.

----------

### Module Manifest

This is a manifested PowerShell module, and the manifest can be found here:

    StoreBroker\StoreBroker.psd1

If you add any new modules/files to this module, be sure to update the manifest as well.
New modules should be added to `NestedModules`, and any new functions or aliases that
should be exported need to be added to the corresponding `FunctionsToExport` or
`AliasesToExport` section.

----------

### Logging

Instead of using the built-in `Write-*` methods (`Write-Host`, `Write-Warning`, etc...),
please use

    Write-Log

which is implemented in Helpers.ps1.  It will take care of formatting your content in a
consistent manner, as well ensure that the content is logged to a file (if configured to do so
by the user).

----------

### PowerShell Version

This module must be able to run on PowerShell version 4.  It is permitted to add functionality
that requires a higher version of PowerShell, but only if there is a fallback implementation
that accomplishes the same thing in a PowerShell version 4 compatible way, and the path choice
is controlled by a PowerShell version check.

For an example of this, see `Write-Log` in `Helpers.ps1` which uses `Write-Information`
for `Informational` messages on v5+ and falls back to `Write-Host` for earlier versions:

    if ($PSVersionTable.PSVersion.Major -ge 5)
    {
        Write-Information $ConsoleMessage -InformationAction Continue
    }
    else
    {
        Write-Host $ConsoleMessage
    }


----------

### Coding Guidelines

As a general rule, our coding convention is to follow the style of the surrounding code.
Avoid reformatting any code when submitting a PR as it obscures the functional changes of your change.

A basic rule of formatting is to use "Visual Studio defaults".
Here are some general guidelines

* No tabs, indent 4 spaces.
* Braces usually go on their own line,
  with the exception of single line statements that are properly indented.
* Use `camelCase` for instance fields, `PascalCase` for function and parameter names
* Avoid the creation of `script` or `global` scoped variables unless absolutely necessary.
  If referencing a `script` or `global` scope variable, be sure to explicitly reference it by scope.
* Avoid more than one blank empty line.
* Always use a blank line following a closing bracket `}` unless the next line itself is a closing bracket.
* Add full [Comment Based Help](https://technet.microsoft.com/en-us/library/hh847834.aspx) for all
  methods added, whether internal-only or external.  The act of writing this documentation may help
  you better design your function.
* File encoding should be ASCII (preferred) or UTF8 (with BOM) if absolutely necessary.
* We try to adhere to the [PoshCode Best Practices](https://github.com/PoshCode/PowerShellPracticeAndStyle/tree/master/Best%20Practices)
  and [DSCResources Style Guidelines](https://github.com/PowerShell/DscResources/blob/master/StyleGuidelines.md)
  and think that you should too.
* We try to limit lines to 100 characters to limit the amount of horizontal scrolling needed when
  reviewing/maintaining code.  There are of course exceptions, but this is generally an enforced
  preference.  The [Visual Studio Productivity Power Tools](https://visualstudiogallery.msdn.microsoft.com/34ebc6a2-2777-421d-8914-e29c1dfa7f5d)
  extension has a "Column Guides" feature that makes it easy to add a Guideline in column 100
  to make it really obvious when coding.

----------

### Code comments

It's strongly encouraged to add comments when you are making changes to the code and tests,
especially when the changes are not trivial or may raise confusion.
Make sure the added comments are accurate and easy to understand.
Good code comments should improve readability of the code, and make it much more maintainable.

That being said, some of the best code you can write is self-commenting.  By refactoring your code
into small, well-named functions that concisely describe their purpose, it's possible to write
code that reads clearly while requiring minimal comments to understand what it's doing.

----------

### Testing

This module supports testing using the Pester UT framework.

If you do not have Pester, download it [here](https://github.com/pester/Pester).
Create a `Pester` folder under any path in `$env:PSModulePath`.
Unzip the contents of the download to the `Pester` folder. 
Pester should now automatically import whenever you run a function from its module.

In the StoreBroker module, the source tree and test tree are children of the project root path.
Working code should be placed under `$root\StoreBroker`.  Tests should be placed under `$root\Tests`.
Each file in the `Tests` folder should test one file in the `StoreBroker` folder.  For example,
the file `$root\StoreBroker\PackageTool.ps1` should have a corresponding file
`$root\Tests\PackageTool.Tests.ps1`.  As the example shows, the filename of the test file
indicates which file from the source tree it is testing.

Tests can be run either from the project root directory or from the `Tests` subfolder.
Navigate to the correct folder and simply run `Invoke-Pester`.

Pester can also be used to test code-coverage, like so:

    Invoke-Pester -CodeCoverage "$root\StoreBroker\PackageTool.ps1" -TestName "*PackageTool*"
    
This command tells Pester to check the `PackageTool.ps1` file for code-coverage.
The `-TestName` parameter tells Pester to run any `Describe` blocks with a `Name` like
`"*PackageTool*"`.

The code-coverage object can be captured and interacted with, like so:

    $cc = (Invoke-Pester -CodeCoverage "$root\StoreBroker\PackageTool.ps1" -TestName "*PackageTool*" -PassThru -Quiet).CodeCoverage
    
There are many more nuances to code-coverage, see
[its documentation](https://github.com/pester/Pester/wiki/Code-Coverage) for more details.

----------

### Releasing

If you are a maintainer:

Ensure that the version number of the module is updated with every pull request that is being
accepted.

This project follows [semantic versioning](http://semver.org/) in the following way:

    <major>.<minor>.<patch>

Where:
* `<major>` - Changes only with _significant_ updates.
* `<minor>` - If this is a feature update, increment by one and be sure to reset `<patch>` to 0.
* `<patch>` - If this is a bug fix, leave `<minor>` alone and increment this by one.

----------

### Legal and Licensing

StoreBroker is licensed under the [MIT license](..\LICENSE).

You will need to complete a Contributor License Agreement (CLA) for any code submissions.
Briefly, this agreement testifies that you are granting us permission to use the submitted change
according to the terms of the project's license, and that the work being submitted is under
appropriate copyright. You only need to do this once.

When you submit a pull request, [@msftclas](https://github.com/msftclas) will automatically
determine whether you need to sign a CLA, comment on the PR and label it appropriately.
If you do need to sign a CLA, please visit https://cla.microsoft.com and follow the steps.