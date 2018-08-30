# StoreBroker PowerShell Module
## Changelog

## [1.19.0](https://github.com/Microsoft/StoreBroker/tree/1.19.0) - (2018/08/30)
### Fixes:

+ Updated `New-ApplicationFlightSubmission` to leverage the new `isMinimalResponse=true` when cloning
  submissions in an attempt to reduce the likelihood of getting a `500` timeout response from
  the service.

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/131) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/ae8e72ad0ac44b71ed6cf4e9064fa63146505a07)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------
## [1.18.1](https://github.com/Microsoft/StoreBroker/tree/1.18.1) - (2018/08/23)
### Fixes:

- Changed how the initial sleep time is determined for retry attempts in order to achieve a better spread amongst clients.

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/127) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/345c521707a0bdbe5b72b8c512771c010d0b5cd4)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------
## [1.18.0](https://github.com/Microsoft/StoreBroker/tree/1.18.0) - (2018/08/07)
### Fixes:

+ Updated `New-ApplicationSubmission` to leverage the new `isMinimalResponse=true` when cloning
  submissions in an attempt to reduce the likelihood of getting a `500` timeout response from
  the service.
- Fixed conflicting AccessToken caching logic between `Get-AccessToken` and `Start-SubmissionMonitor`.
- Fixed issue in `Format-ApplicationSubmission` that incorrectly checked for valid trailers.

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/124) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/19a8947d8dc5ac173f683d32afdb40f8daed6dec)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------
## [1.17.0](https://github.com/Microsoft/StoreBroker/tree/1.17.0) - (2018/06/06)
### Fixes:

+ Sped up the module for users not using a Proxy.  `AccessToken` is now cached for the
  duration of the console session, and only needs to be refreshed when it expires (which is about
  every 60 minutes).  Previously, the access token was only cached for the duration of the currently
  executing command, which meant that any succesive interactions at the commandline required a new
  `AccessToken` to be acquired.

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/120) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/35a953869ea70fc8fab575f4a5a0b919d0d9cfe1)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------
## [1.16.4](https://github.com/Microsoft/StoreBroker/tree/1.16.4) - (2018/04/23)
### Fixes:

- Removed checks validation checks which had prevented some apps from updating
  gaming options or trailers.  The API now enables all apps to use
  trailers and gaming options, even if their submission object doesn't
  provide those nodes.

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/116) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/b11f0a4932717ba6d6500529303724bfaef40920)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------
## [1.16.3](https://github.com/Microsoft/StoreBroker/tree/1.16.3) - (2018/04/10)
### Fixes:

- There was an error in `Update-ApplicationSubmission` where it checked for
  `-UpdateGamingOptions` for both updating gaming options as well as for
  updating trailers, where it should have been checking `-UpdateTrailers`
  for the trailers portion.

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/115) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/01dbbd14b313fe9472e2cfc74bb084b4b8a4a7cf)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.16.2](https://github.com/Microsoft/StoreBroker/tree/1.16.2) - (2018/04/06)
### Fixes:

- Fixed error (`You cannot call a method on a null-valued expression.`) seen during packaging
  if a trailer element didn't have loc comments/attributes in it.  Packaging should now be
  completely agnostic to whether loc comments/attributes exist or not.

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/112) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/1f051e4e102cd8bacf18503f10900af9090ee326)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.16.1](https://github.com/Microsoft/StoreBroker/tree/1.16.1) - (2018/02/15)
### Fixes:

- Fix (ignorable) exception seen in `ConvertFrom-ExistingSubmission` when trying to
  convert non-existant trailer data for a submission without Advanced Listing support.

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/110) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/e9b8b2be101b8c3d2140798d6be5aeca1b0a0474)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.16.0](https://github.com/Microsoft/StoreBroker/tree/1.16.0) - (2018/02/14)
### Features:

+ Add remaining localizable text fields, so that StoreBroker can now modify every aspect of a subimission (exposed by the API)
+ Support added for the following fields: `minimumHardware`, `shortDescription`, `shortTitle`, `sortTitle`, `voiceTitle`, `devStudio`

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/108) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/2dcce9c06e086b70a90e31144b57d8d3ecd9ad07)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.15.1](https://github.com/Microsoft/StoreBroker/tree/1.15.1) - (2018/02/12)
### Features:

+ Add `-Force` switch to `Join-SubmissionPackage`, enabling you to overwrite an existing file

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/106) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/fb0764a4a14756fcd3161ca72630dafd5074063e)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.15.0](https://github.com/Microsoft/StoreBroker/tree/1.15.0) - (2018/02/07)
### Features:

+ Add full support for "Advanced Listings"
+ Users can now query and update Gaming options and trailers (if supported by their app)
+ Additionally adds support for all "additional asset" image types (like Hero images)

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/100) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/f05341809f8a72168c30408e6025762934a018dc) | [[issue 1]](https://github.com/Microsoft/StoreBroker/issues/58) | [[issue 2]](https://github.com/Microsoft/StoreBroker/issues/85)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.14.4](https://github.com/Microsoft/StoreBroker/tree/1.14.4) - (2018/02/07)
### Fixes:

- Fix exception that occurred when trying to log non-standard server errors
- Fix potential infinite retry loop when an exception like that occurs

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/104) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/c62dc3e78b5ff135e75fb5c56f6ddce6681f6dfb)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.14.3](https://github.com/Microsoft/StoreBroker/tree/1.14.3) - (2018/02/07)
### Fixes:

+ The loc team's parser expects the loc comments to be directly before the content that the comment refers to.
+ Updates `ConvertFrom-Existing*Submission` to place the comments in the right position
+ Updates the sample PDP xml files.

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/101) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/59d15a30156164d0b5f308eaa424608d46b2fbd0)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.14.2](https://github.com/Microsoft/StoreBroker/tree/1.14.2) - (2018/02/05)
### Fixes:

- Fix issue with linefeeds for certain messages being sent to `Write-Log` after the changes from `1.14.0`

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/102) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/95b2cd90118e55a26b5b9221895d23e02707d213)

Author: [**@danbelcher-MSFT**](https://github.com/danbelcher-MSFT)

------

## [1.14.1](https://github.com/Microsoft/StoreBroker/tree/1.14.1) - (2018/02/02)
### Fixes:

+ Change default polling interval in `Start-SubmissionMonitor` from 1 to 5 minutes (specifiable via new parameter)

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/98) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/97ffc8aeb78e11385948754677ec94240c8683f6)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.14.0](https://github.com/Microsoft/StoreBroker/tree/1.14.0) - (2018/01/29)
### Features:

+ Improves our error log reporting by better capturing the specific-line that an exception was originally thrown from

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/97) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/340981eabf0663c774e7bc3e01591ab8d12664de)

Author: [**@danbelcher-MSFT**](https://github.com/danbelcher-MSFT)

------

## [1.13.0](https://github.com/Microsoft/StoreBroker/tree/1.13.0) - (2018/01/22)
### Features:

+ Add auto-retry logic with exponential backoff when API responses fail due to specific, user-configurable error codes

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/94) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/d13cc9dcc8ddbffa53de7e2d7971f49e3607c8ae) | [[issue]](https://github.com/Microsoft/StoreBroker/issues/92)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.12.4](https://github.com/Microsoft/StoreBroker/tree/1.12.4) - (2018/01/16)
### Fixes:

- When handling appx metadata, assume `neutral` for architecture if not otherwise specified.  Prevents an exception when we try to rename the package

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/90) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/4405654aa382c56de13b3070d9bf587bd3dc3850) | [[issue]](https://github.com/Microsoft/StoreBroker/issues/89)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.12.3](https://github.com/Microsoft/StoreBroker/tree/1.12.3) - (2018/01/03)
### Fixes:

- Fixes an exception due to logging only seen if calling `Update-*Submission` and specyfing a `SubmissionId`

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/83) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/06d1fe4b127690ba03423e0e6cbc812a7dc2bd01)

Author: [**@danbelcher-MSFT**](https://github.com/danbelcher-MSFT)

------

## [1.12.2](https://github.com/Microsoft/StoreBroker/tree/1.12.2) - (2017/12/14)
### Fixes:

- We added an exception in `1.12.0` if more than one image with the same name was found within a language sub-directory of `ImagesRootPath`.  This was a breaking change however, so this moves that exception to be a warning instead.

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/84) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/4e60c5dee29017dd3157d90cfff3a97f8103b954)

Author: [**@danbelcher-MSFT**](https://github.com/danbelcher-MSFT)

------

## [1.12.1](https://github.com/Microsoft/StoreBroker/tree/1.12.1) - (2017/12/06)
### Fixes:

- Re-enable support (lost in `1.12.0`) for the undocumented ability to use an empty value for `Release` in PDP files (meaning that images can be stored directly in `ImagesRootPath`)

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/81) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/3df8b3f760635292d6de0cfb3ac4e2526b550733)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.12.0](https://github.com/Microsoft/StoreBroker/tree/1.12.0) - (2017/12/05)
### Fixes:

- Enable "Fallback Language" support for media: You can now use the exact same screenshots for multiple languages, simplifying authoring time and reducing your package size.

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/80) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/2a3c11f90cd72e044541add5cef3882322701b7d) | [[issue]](https://github.com/Microsoft/StoreBroker/issues/28)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.11.7](https://github.com/Microsoft/StoreBroker/tree/1.11.7) - (2017/12/04)
### Fixes:

- Add helpful error message to users calling `Update-*Submission` with `-AddPackages` or `-ReplacePackages` when their StoreBroker payload doesn't have any package information

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/79) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/e1aa2d34b7b6f6424b5baa69f8f77c0c1c50aa8c)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.11.6](https://github.com/Microsoft/StoreBroker/tree/1.11.6) - (2017/11/30)
### Fixes:

- Fix unformatted error message when calling `New-*SubmissionPackage` without specifying `OutPath`

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/78) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/6a2884d31feb8e5621131688389abacbf2a6cea3)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.11.5](https://github.com/Microsoft/StoreBroker/tree/1.11.5) - (2017/11/10)
### Fixes:

- Fix how we reference "special folders" (like Desktop, Documents) for users who relocate those folders to a different location

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/77) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/37508946a2d3980c005e335212010be3e4f53cf8)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.11.4](https://github.com/Microsoft/StoreBroker/tree/1.11.4) - (2017/11/06)
### Fixes:

- Prevent the check for values in global vars from going into `$global:Error`

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/75) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/77b5ef397a47a5bf0f93c788eea9f95e9808e04b)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.11.3](https://github.com/Microsoft/StoreBroker/tree/1.11.3) - (2017/11/06)
### Fixes:

- Fixes error introduced in `1.11.2` when trying to access the `RawStream` for errors

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/76) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/9c7756ffb417e5691f84eec9ce4b4a8bee465671)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.11.2](https://github.com/Microsoft/StoreBroker/tree/1.11.2) - (2017/10/27)
### Fixes:

- Captures to the log the `activityId` returned by the API on `500` / `Internal Server Error` failures

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/73) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/36384212b617d3a565b9a7427729bad1e93efd18) | [[issue]](https://github.com/Microsoft/StoreBroker/issues/72)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.11.1](https://github.com/Microsoft/StoreBroker/tree/1.11.1) - (2017/10/24)
### Fixes:

- Fixes the additional metadata being written as of `1.6.0`.

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/70) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/c8b643c8d64037b0bdaf820b90989b627cbc2160)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.11.0](https://github.com/Microsoft/StoreBroker/tree/1.11.0) - (2017/10/13)
### Features:

- Support relative paths that don't begin with a `.` (denoting the current working directory)

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/67) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/7378e93cf74fa54a0b088f9938fd1c489800957d) | [[issue]](https://github.com/Microsoft/StoreBroker/issues/64)

Author: [**@danbelcher-MSFT**](https://github.com/danbelcher-MSFT)

------

## [1.10.1](https://github.com/Microsoft/StoreBroker/tree/1.10.1) - (2017/10/06)
### Fixes:

- `Write-Log` (an internal helper) no longer errors on empty content (which had been causing unhelpful error messages for users providing bad input)

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/65) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/a6fc80be05e731d3d66d6f47de720a8f9214d914) | [[issue]](https://github.com/Microsoft/StoreBroker/issues/63)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.10.0](https://github.com/Microsoft/StoreBroker/tree/1.10.0) - (2017/09/29)
### Features:

+ Add new `$global:SBShouldLogPid` option to capture the ProcessId with each log entry

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/62) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/e55f267a557b8fa61e0d25bd523520395cfced69)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.9.0](https://github.com/Microsoft/StoreBroker/tree/1.9.0) - (2017/09/19)
### Features:

+ Packaging performance improvements with `New-*SubmissionPackage`

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/59) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/43fa8dde3267bf0e06ec44d7bfad93190416f83d)

Author: [**@danbelcher-MSFT**](https://github.com/danbelcher-MSFT)

------

## [1.8.4](https://github.com/Microsoft/StoreBroker/tree/1.8.4) - (2017/09/07)
### Fixes:

+ Store made `SupportContactInfo` a required field.  Updating PDP schema

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/56) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/37a533aea4d3d3914de1fc1a76a462cc0f63b03a)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.8.3](https://github.com/Microsoft/StoreBroker/tree/1.8.3) - (2017/07/11)
### Fixes:

+ Removed the use of "Halt Execution" exection messages, and now exceptions have the same string content as the `Write-Error` message.

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/57) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/6c8bed3983f2d4e1156ee825dd141057e1b5a5d2)

Author: [**@jowis41**](https://github.com/jowis41)

------

## [1.8.2](https://github.com/Microsoft/StoreBroker/tree/1.8.2) - (2017/06/29)
### Fixes:

+ Store reduced keyword max length to 30 characters.  Updating PDP schema and samples

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/51) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/e1dc3e911d7455ed4a5de03886297b5ed8b3cb57)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.8.1](https://github.com/Microsoft/StoreBroker/tree/1.8.1) - (2017/05/02)
### Fixes:

+ `Start-SubmissionMonitor` can now return the final submission object retrieved if you provide `-PassThru`

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/45) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/d5dee775681e8a1e64a3dd961e20e236c468a8e4) | [[issue]](https://github.com/Microsoft/StoreBroker/issues/43)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.8.0](https://github.com/Microsoft/StoreBroker/tree/1.8.0) - (2017/05/02)
### Features:

+ Migrated to Azure Storage Data Movement Library for significantly faster uploads

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/48) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/0b260c47dd84ce6f85063acdfe8b3c4477793e66) | [[issue]](https://github.com/Microsoft/StoreBroker/issues/47)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.7.1](https://github.com/Microsoft/StoreBroker/tree/1.7.1) - (2017/04/19)
### Fixes:

+ Updated to support publishing module as a [NuGet](https://www.nuget.org/packages/Microsoft.Windows.StoreBroker/)

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/30) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/3ad0efac0811900c7a9ac44556d31fec61144158) | [[issue]](https://github.com/Microsoft/StoreBroker/issues/1)

Author: [**@danbelcher-MSFT**](https://github.com/danbelcher-MSFT)

------

## [1.7.0](https://github.com/Microsoft/StoreBroker/tree/1.7.0) - (2017/04/04)
### Fixes:

+ Added `Open-Store` command

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/42) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/f567b919cebc0c7517516d96485e8dd04b534247)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.6.1](https://github.com/Microsoft/StoreBroker/tree/1.6.1) - (2017/03/28)
### Fixes:

+ Add support for `.appxupload` files

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/41) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/819e18d638d15bbbee192d8ced167f501be3c766)

Author: [**@danbelcher-MSFT**](https://github.com/danbelcher-MSFT)

------

## [1.6.0](https://github.com/Microsoft/StoreBroker/tree/1.6.0) - (2017/03/23)
### Fixes:

- `New-SubmissionPackage` now writes additional package metadata to the generated json file

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/39) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/391954b962756b1f222d2e4e45aa6d203b805db4) | [[issue]](https://github.com/Microsoft/StoreBroker/issues/16)

Author: [**@danbelcher-MSFT**](https://github.com/danbelcher-MSFT)

------

## [1.5.1](https://github.com/Microsoft/StoreBroker/tree/1.5.1) - (2017/03/15)
### Fixes:

- Fix default NuGet download path for interactive console users

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/40) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/cfa6ae41394ccbdd9102cab5285bed41b18f7ca1)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.5.0](https://github.com/Microsoft/StoreBroker/tree/1.5.0) - (2017/03/15)
### Features:

+ Add `$global:SBWebRequestTimeoutSec` option

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/36) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/7b16e6e6b321e7d3098a04493de02176e367fce2)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.4.7](https://github.com/Microsoft/StoreBroker/tree/1.4.7) - (2017/03/11)
### Fixes:

- Fix behavior of `Resolve-UnverifiedPath` (added in `1.4.4`)

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/38) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/43a0553386943f1941a0f0184187ac56973fc3ff)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.4.6](https://github.com/Microsoft/StoreBroker/tree/1.4.6) - (2017/03/10)
### Fixes:

- Update `Invoke-WebRequest` to use `-UseBaseParsing` for systems where the IE engine is not available

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/37) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/dd514956b37233d37b25f45d793bd165715770fb)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.4.5](https://github.com/Microsoft/StoreBroker/tree/1.4.5) - (2017/03/09)
### Fixes:

- Update pricing tier documentation reference

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/35) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/3e0873df4b0986b550846c7607d0b83ba62e5fb7)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.4.4](https://github.com/Microsoft/StoreBroker/tree/1.4.4) - (2017/03/09)
### Fixes:

- Enable relative package paths for uploading/downloading.

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/34) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/2a86150d134d3f0a1552b00b199dd252a6092a04)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.4.3](https://github.com/Microsoft/StoreBroker/tree/1.4.3) - (2017/03/08)
### Fixes:

- Fix reported telemetry in `Update-InAppProductSubmission`

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/33) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/cae225325651abf083b2a0409f03d5dc8ceb473c)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.4.2](https://github.com/Microsoft/StoreBroker/tree/1.4.2) - (2017/03/08)
### Fixes:

- Fixes "Cannot index into a null array" when no headers exist in WebExcepton response

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/32) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/ad5750e570401bcbc4671cf921b5830e47fff6ab)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.4.1](https://github.com/Microsoft/StoreBroker/tree/1.4.1) - (2017/03/07)
### Fixes:

- Fix `charset` referenced in `Invoke-WebRequest` (was using `utf8` vs `UTF-8`)

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/31) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/b5269b26a15e02f2886e6af4b7f47471af9d5802)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.4.0](https://github.com/Microsoft/StoreBroker/tree/1.4.0) - (2017/03/07)
### Features:

+ Log MS-CorrelationId with each API request (aids post-mortem debugging with the Submission API team)

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/29) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/0b7dc94e3bfc8cbe8c7752a4094a46864ab2876d)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.3.0](https://github.com/Microsoft/StoreBroker/tree/1.3.0) - (2017/03/01)
### Features:

+ Add Mandatory Update and Package Rollout support

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/26) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/01dafbedc19a32975371eca87b80cc78c4a001c0) | [[issue]](https://github.com/Microsoft/StoreBroker/issues/2)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.2.2](https://github.com/Microsoft/StoreBroker/tree/1.2.2) - (2017/02/20)
### Fixes:

+ Clarify behavior of Dev Portal with new submissions

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/25) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/69dc329d5ff40008119484a1f459ef12a858d1df)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.2.1](https://github.com/Microsoft/StoreBroker/tree/1.2.1) - (2017/02/17)
### Fixes:

+ Properly escape special characters when generating config files

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/24) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/92e1014b776d871d37a2e386068f1d17d3a208ea)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.2.0](https://github.com/Microsoft/StoreBroker/tree/1.2.0) - (2017/02/10)
### Features:

+ Added support for accessing multiple tenants within a single proxy

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/22) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/92e1014b776d871d37a2e386068f1d17d3a208ea)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.1.3](https://github.com/Microsoft/StoreBroker/tree/1.1.3) - (2017/02/08)
### Fixes:

+ Static Analysis changes

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/18) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/67b18390868062e297cdaaee076e1c4d279c7671)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.1.2](https://github.com/Microsoft/StoreBroker/tree/1.1.2) - (2017/02/01)
### Fixes:

+ Prevent console messages from being printed if host is non-interactive

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/13) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/5fcff1418c153b8aa3ffa223d202497eca66b6dd) | [[issue]](https://github.com/Microsoft/StoreBroker/issues/12)

Author: [**@lisaong**](https://github.com/lisaong)

------

## [1.1.1](https://github.com/Microsoft/StoreBroker/tree/1.1.1) - (2017/01/27)
### Fixes:

+ Add a logger option to print timestamps in UTC for log traces

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/15) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/aff905a71989b7eecc2345f0fcb18b74ca099053) | [[issue]](https://github.com/Microsoft/StoreBroker/issues/10)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

------

## [1.1.0](https://github.com/Microsoft/StoreBroker/tree/1.1.0) - (2017/01/25)
### Features:
+ Added support for IAP's (In-App Products)

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/11) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/52585e1e34d846558552b9e9f69d74380553ef69) }| [[issue]](https://github.com/Microsoft/StoreBroker/issues/3)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)

### Fixes:

- Stopped exporting `DeepCopy-Object` (was causing incompatibility issues)

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/6) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/6ce403dd054c263ff33dfaa89fed8e60c2a447fb)

Author: [**@danbelcher-MSFT**](https://github.com/danbelcher-MSFT)

------

## [1.0.1](https://github.com/Microsoft/StoreBroker/tree/1.0.1) - (2016/12/08)
### Fixes:
+ Exported `DeepCopy-Object`

More Info: [[pr]](https://github.com/Microsoft/StoreBroker/pull/5) | [[cl]](https://github.com/Microsoft/StoreBroker/commit/96d5ec42f7825b5a7f995623bb9a9b6291ad8b60)

Author: [**@lisaong**](https://github.com/lisaong)

------

## [1.0.0](https://github.com/Microsoft/StoreBroker/tree/1.0.0) - (2016/11/29)
### Features:
+ Initial public release

More Info: [[cl]](https://github.com/Microsoft/StoreBroker/commit/fb623841b75cd82f05507dc3068838956a2a466a)

Author: [**@HowardWolosky**](https://github.com/HowardWolosky)
