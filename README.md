# github-action-push-file-to-another-repository

The purpose of this forked GitHub Action was to allow copying of a single file and renaming of that file to another repo. This can be used with an API token or SSH key to push changes to another repo.

## Examples

Push the README.md to the dest-repo-name/folder/subfolder with the name of github-action-push-file-to-another-repository.md

``` yaml
file-push:
    runs-on: ubuntu-latest
    steps:
        - uses: actions/checkout@v3
        - uses: g1t-out/github-action-push-file-to-another-repository@main
            env:
                SSH_DEPLOY_KEY: ${{ secrets.MY_DEPLOY_KEY }}
            with:
                source-filepath: './README.md'
                destination-github-username: 'my-user'
                destination-repository-name: 'dest-repo-name'
                user-email: 'myemail@mydomain.com'
                target-directory: '/folder/subfolder'
                target-filename: ${{ format('{0}.md', github.event.repository.name )}}

```

## Docs for the original forked version.
See the extensive documentation in https://cpina.github.io/push-to-another-repository-docs/ (includes examples, FAQ, troubleshooting, etc.).

GitHub repository of the documentation: https://github.com/cpina/push-to-another-repository-docs
