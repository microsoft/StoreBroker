# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

# Need to split-path $MyInvocation.MyCommand.Path twice and then add StoreBroker folder
$sbModulePath = Join-Path ($MyInvocation.MyCommand.Path | Split-Path -Parent | Split-Path -Parent) "StoreBroker"

Import-Module $sbModulePath

InModuleScope StoreBroker {

    Describe "PackageTool" {

        Context "Remove-Comment" {

            It "does not change text with no comments" {
                $in = "This is a test string with no comments."

                $in | Remove-Comment | Should BeExactly $in
            }

            It "does not change multiple lines of text with no comments" {
                $in = @(
                    "This is a",
                    "test string split",
                    "across multiple lines",
                    "and with no comments"
                )

                $out = $in | Remove-Comment
                
                # Assert the collection size is the same
                $out.Count | Should Be $in.Count

                # Assert the content is the same
                foreach ($i in 0..($in.Count - 1))
                {
                    $out[$i] | Should BeExactly $in[$i]
                }
            }

            It "removes comments from a single line of text" {
                $content = "This is valid content"
                $comment = "// this is comment content // and so is this"
                $in = $content + $comment

                $in | Remove-Comment | Should BeExactly $content
            }

            It "removes comments from multiple lines of text" {
                $content = @(
                    "Here is some      ",
                    "example text      ",
                    "that occurs across",
                    "multiple lines    "
                )

                $comments = @(
                    "// None of the text  ",
                    "//     in this array",
                    "//is considered",
                    "//   valid."
                )

                $in = @()
                foreach ($i in 0..($content.Count - 1))
                {
                    $in += ($content[$i] + $comments[$i])
                }

                $out = $in | Remove-Comment

                # Assert the collection size is the same
                $out.Count | Should Be $content.Count

                # Assert the content is the same
                foreach ($i in 0..($in.Count-1))
                {
                    $out[$i] | Should BeExactly $content[$i]
                }
            }

            It "removes empty strings and whitespace across multiple lines" {
                $in = @(
                    "",
                    " ",
                    "    "
                )

                $in | Remove-Comment | Should Be $null
            }

            It "returns nothing when all lines are comments" {
                $in = @(
                    "// None of the text  ",
                    "//     in this array",
                    "//is considered",
                    "//   valid."
                )

                $in | Remove-Comment | Should Be $null
            }
        }
    }
}
