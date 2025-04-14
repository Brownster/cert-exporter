BeforeAll {
    . "$PSScriptRoot/../cert-exporter.ps1"
}

Describe 'Sanitize-LabelValue' {
    It 'removes newlines, tabs, and quotes, and truncates long label values' {
        $input = "foo`nbar`t\"baz\"" + ('x' * 210)
        $result = Sanitize-LabelValue $input
        $result | Should -NotMatch '\n|\t'
        $result | Should -NotMatch '"'
        $result.Length | Should -BeLessThanOrEqual 200
    }
}
