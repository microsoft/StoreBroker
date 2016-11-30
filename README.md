# StoreBroker PowerShell Module

#### Table of Contents

* [Overview](#overview)
    *   [Project Status](#project-status)
    *   [Goals](#goals)
    *   [Current Functionality](#current-functionality)
        *   [Limitations](#limitations)
    *   [Prerequisites](#prerequisites)
*   [Installation and Setup](#installation-and-setup)
*   [Usage](#usage)
*   [Developing and Contributing](#developing-and-contributing)
*   [Legal and Licensing](#legal-and-licensing)
*   [Governance](#governance)
*   [Code of Conduct](#code-of-conduct)
*   [Privacy Policy](#privacy-policy)

----------

## Overview

StoreBroker is a [PowerShell](https://microsoft.com/powershell) [module](https://technet.microsoft.com/en-us/library/dd901839.aspx)
that provides command-line interaction and automation for Application and In-App Purchase
submissions to the Windows Store via the
[Windows Store Submission API](https://msdn.microsoft.com/windows/uwp/monetize/create-and-manage-submissions-using-windows-store-services).

It's designed for all Windows developers that publish their apps into the Windows Store.

Most Microsoft-published applications in the Windows Store have metadata (screenshots, captions,
descriptions, feature lists, etc...) localized across 64 languages; updating all of these values
manually through the [Developer Portal](https://dev.windows.com) can take hours (or days).
StoreBroker is able to complete a full metadata update in a matter of minutes with just two
commands, and that's just the start of what it can do.

### Project Status

**Production**

This module is **actively used within Microsoft** as the _primary way_ that our first-party
application teams submit flight updates and public submission updates to the Windows Store,
and is now available to the general developer community to leverage as well.

### Goals

**StoreBroker** should ...

... have full support for exercising every aspect of the Windows Submission API.

... be easy to use, and consistent in its functionality.

... save developer time and decrease the friction with getting updates to the Windows Store.

### Current Functionality

At a very high level, this is what you can do with StoreBroker:

 - App Submissions
    - Retrieve / Create / Update / Remove

 - Flights
    - Retrieve / Create / Update / Remove

 - Flight Submissions
    - Retrieve / Create / Update / Remove

 - In-App Products (IAP's)
    - Retrieve / Create / Update / Remove

 - In-App Product (IAP) Submissions
    - Retrieve / Create / Update / Remove

 - General
    - Submission Monitor with email support

#### Limitations

At this time, we don't have support for these newest additions to the API, but they are on our
[backlog to add](https://github.com/Microsoft/StoreBroker/issues/2):

  - Package Rollout
  - Mandatory Update

Also of note:

We have full support for IAP's, but unlike App Submissions and Flights, we do not yet have
a [PDP](Documentation/PDP.md) format for IAP metadata, nor a function like `New-SubmissionPackage`
to generate the json/zip payload that the IAP functions require.  This is
[on our backlog](https://github.com/Microsoft/StoreBroker/issues/3) as well.

### Prerequisites

This module requires PowerShell [version 4](https://en.wikipedia.org/wiki/PowerShell#PowerShell_4.0)
or higher.

[More prerequisites](Documentation/SETUP.md#prerequisites) are covered in
[SETUP.md](Documentation/SETUP.md#prerequisites).

----------

## Installation and Setup

Refer to [SETUP.md](Documentation/SETUP.md) for the Installation and Setup instructions.

----------

## Usage

Refer to [USAGE.md](Documentation/USAGE.md) for usage information.

----------

## Developing and Contributing

Please see the [Contribution Guide](CONTRIBUTING.md) for information on how to develop and
contribute.

If you have any problems, please consult [GitHub Issues](https://github.com/Microsoft/StoreBroker/issues),
and the [FAQ](Documentation/USAGE.md#faq).

If you do not see your problem captured, please file [feedback](CONTRIBUTING.md#feedback).

----------

## Legal and Licensing

StoreBroker is licensed under the [MIT license](LICENSE).

-------------------

## Governance

Governance policy for the StoreBroker project is described [here](Documentation/GOVERNANCE.md).

----------

## Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/)
or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions
or comments.

----------

## Privacy Policy

For more information, refer to Microsoft's [Privacy Policy](https://go.microsoft.com/fwlink/?LinkID=521839).