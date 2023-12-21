// Cron to make a PR to update the semgrep/tests/semgrep-rules
// submodule to its latest version. This will allow to detect ASAP (or at
// least not too late) when semgrep-core can't check all the rules and tests
// in semgrep-rules (which are updated frequently).
//
// Note that semgrep-rules CI itself is testing whether
// the latest develop docker image of semgrep can check semgrep-rules, so
// we should rarely get regressions when updating the semgrep-rules submodule.

local semgrep = import "libs/semgrep.libsonnet";

// ----------------------------------------------------------------------------
// Main job
// ----------------------------------------------------------------------------

local job = {
  'runs-on': 'ubuntu-latest',
  steps: [
    // The 2 steps below allow then later to trigger a PR (using 'gh')
    // from a workflow by (ab)using our Semgrep-CI Github App.
    // The PR will come from "Semgrep-CI bot".
    //
    // This is quite complicated and CircleCI is far simpler
    // for those kinds of things (see semgrep-pro/.circleci/config.yml
    // for an example of such cron simply using circleci/github-cli orb
    semgrep.github_bot.get_jwt_step,
    semgrep.github_bot.get_token_step,
    // Recursively checkout all submodules
    // ensure that we're on the default branch (develop)
    // Use the token provided by the JWT token getter above
    {
      uses: 'actions/checkout@v3',
      with: {
        submodules: 'recursive',
        // By default actions/checkout will checkout on the pull_request branch (e.g., 'cron').
        // Here instead we want 'develop' (or whatever the name of the current default branch).
        // Why not simply do 'git checkout develop' in another step after?
        // Because this would require some form of configuring URLs or auth using
        // the token, and so 'ref:' and 'token:' below handles that for us instead.
        ref: '${{ github.event.repository.default_branch }}',
        token: semgrep.github_bot.token_ref,
      },
    },
    {
      name: 'Update semgrep-rules (the main purpose of this workflow)',
      run: 'make update_semgrep_rules',
      env: {
	GITHUB_TOKEN: semgrep.github_bot.token_ref,
       },
    },
    //alternative way to do it:
    //working-directory: ./tests/semgrep-rules
    //run: |
    //  git checkout develop
    //  git pull
    //just for debugging
    // - run: echo FOO >> README.md
    {
      run: 'git status',
    },
    // from https://ao.ms/how-to-use-git-commit-in-github-actions/
    {
      name: 'Creating the branch and commiting to it',
      env: {
        BRANCHNAME: 'update-semgrep-rules-${{ github.run_id }}-${{ github.run_attempt }}',
	GITHUB_TOKEN: semgrep.github_bot.token_ref,
      },
      run: |||
        git checkout -b $BRANCHNAME
        git config user.name "GitHub Actions Bot"
        git config user.email "<>"
        git commit -a -m"update semgrep rules"
        git push origin $BRANCHNAME
      |||,
    },
    //TODO: using EndBug/add-and-commit below does not currently work, I get:
    //  Errors during submodule fetch:
    //    tests/semgrep-rules
    //    pfff
    // even with the GITHUB_TOKEN passed
    //TODO
    //  # We could do the 'git add' ourselves, but we also need to handle the case where
    //  # nothing is available to commit (semgrep-rules has not been updated) and
    //  # EndBug/add-and-commit handles that automatically
    //  # See https://github.com/EndBug/add-and-commit
    //  uses: EndBug/add-and-commit@v9
    //  with:
    //    add: README.md tests/semgrep-rules
    //    author_name: ${{ github.actor }}
    //    author_email: ${{ github.actor }}@users.noreply.github.com
    //    message: "chore: Bump Semgrep Rules Submodule"
    //    new_branch: update-semgrep-rules-${{ github.run_id }}-${{ github.run_attempt }}
    //  env: auth.github_token
    {
      name: 'Create the Pull request with gh',
      // Use the token generated from the semgrep-ci Github App - this ensures
      // that PR checks will run on the PR opened by this workflow!
      //TODO: the '--reviewer r2c/pa' does not seem to work
      env: {
	GITHUB_TOKEN: semgrep.github_bot.token_ref,
      },
      run: |||
        gh pr create --title 'Cron - update semgrep-rules' --body 'Please confirm correctness of the changes here and ensure all tests pass. This PR was autogenerated by .github/workflows/update-semgrep-rules.yml' --base develop
      |||,
    },
  ],
};

// ----------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------

{
  name: 'update-semgrep-rules',
  on: {
    // Allow for manual triggering in https://github.com/returntocorp/semgrep/actions
    // See https://docs.github.com/en/actions/managing-workflow-runs/manually-running-a-workflow
    workflow_dispatch: {},
    // This push-event trigger is useful to test improvements to the workflow by pushing to this
    // special 'cron' branch. We do that for our parsing-stat crons and it avoids to have
    // to wait for the cron to kick in at the scheduled time.
    // TODO: not sure why, but using 'pull_request' instead of 'push' does not work
    push: {
      branches: [
        'cron',
      ],
    },
    schedule: [
      {
        // cron table memento below
        // (src: https://dev.to/anshuman_bhardwaj/free-cron-jobs-with-github-actions-31d6)
        // ┌────────── minute (0 - 59)
        // │ ┌────────── hour (0 - 23)
        // │ │ ┌────────── day of the month (1 - 31)
        // │ │ │ ┌────────── month (1 - 12)
        // │ │ │ │ ┌────────── day of the week (0 - 6)
        // │ │ │ │ │
        // │ │ │ │ │
        // │ │ │ │ │
        // * * * * *
        //
        // This cron runs at 00:00 UTC every monday/wed/fri
        cron: '0 0 * * 0,2,4',
      },
    ],
  },
  //TODO: how to handle failures if the cron fails? Who gets the error notification?
  jobs: {
    job: job,
  },
}
