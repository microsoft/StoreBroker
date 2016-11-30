# StoreBroker PowerShell Module
## Governance

## Terms

* [**StoreBroker Committee**](#storebroker-committee): A committee of project owners who are
  responsible for design decisions, and approving new maintainers/committee members.

* **Project Leads**: Project Leads support the StoreBroker Committee, engineering teams, and
  community by working across Microsoft teams and leadership, and working through issues with
  other companies. The initial Project Leads for StoreBroker are
  Howard Wolosky ([HowardWolosky-MSFT](https://github.com/HowardWolosky-MSFT)) and
  Daniel Belcher ([DanBelcher-MSFT](https://github.com/DanBelcher-MSFT)).

* [**Repository maintainer**](#repository-maintainers): An individual responsible for merging
  pull requests (PRs) into `master` when all requirements are met (code review, tests, docs,
  as applicable).  Repository Maintainers are the only people with write permissions into `master`.

* [**Area experts**](#area-experts): People who are experts for specific components or
  technologies (e.g. security, performance). Area experts are responsible for code reviews,
  issue triage, and providing their expertise to others. 

* **Corporation**: The Corporation owns the StoreBroker repository and, under extreme circumstances,
  reserves the right to dissolve or reform the StoreBroker Committee, the Project Leads, and the
  Corporate Maintainer.  The Corporation for StoreBroker is Microsoft.

* **Corporate Maintainer**: The Corporate Maintainer is an entity, person or set of persons, with
  the ability to veto decisions made by the StoreBroker Committee or any other collaborators on the
  StoreBroker project.  This veto power will be used with restraint since it is intended that the
  community drive the project.  The Corporate Maintainer is determined by the Corporation both
  initially and in continuation.  The initial Corporate Maintainer for StoreBroker is
  Howard Wolosky ([HowardWolosky-MSFT](https://github.com/HowardWolosky-MSFT)).

## StoreBroker Committee

The StoreBroker Committee and its members (aka Committee Members) are the primary caretakers of
StoreBroker.

### Current Committee Members

 * Howard Wolosky ([HowardWolosky-MSFT](https://github.com/HowardWolosky-MSFT))
 * Daniel Belcher ([DanBelcher-MSFT](https://github.com/DanBelcher-MSFT)).

### Committee Member Responsibilities

Committee Members are responsible for reviewing and approving proposed new features or design changes. 

#### Committee Member DOs and DON'Ts 

As a StoreBroker Committee Member:

1. **DO** reply to issues and pull requests with design opinions
  (this could include offering support for good work or exciting new features)
2. **DO** encourage healthy discussion about the direction of StoreBroker
3. **DO** raise "red flags" on PRs that require a larger design discussion
4. **DO** contribute to documentation and best practices
5. **DO** maintain a presence in the StoreBroker community outside of GitHub
   (Twitter, blogs, StackOverflow, Reddit, Hacker News, etc.)
6. **DO** heavily incorporate community feedback into the weight of your decisions
7. **DO** be polite and respectful to a wide variety of opinions and perspectives
8. **DO** make sure contributors are following the [contributor guidelines](../CONTRIBUTING.md)
9. **DON'T** constantly raise "red flags" for unimportant or minor problems to the point that the
   progress of the project is being slowed
10. **DON'T** offer up your opinions as the absolute opinion of the StoreBroker Committee.
   Members are encouraged to share their opinions, but they should be presented as such.

### StoreBroker Committee Membership

The initial StoreBroker Committee consists of Microsoft employees.
It is expected that over time, StoreBroker experts in the community will be made Committee Members. 
Membership is heavily dependent on the level of contribution and expertise:
individuals who contribute in meaningful ways to the project will be recognized accordingly. 

At any point in time, a Committee Member can nominate a strong community member to join the Committee. 
Nominations should be submitted in the form of an `Issue` with the `committee nomination` label
detailing why that individual is qualified and how they will contribute.  After the `Issue` has
been discussed, a unanimous vote will be required for the new Committee Member to be confirmed. 

## Repository Maintainers

Repository Maintainers are trusted stewards of the StoreBroker repository responsible for
maintaining consistency and quality of the code. 

One of their primary responsibilities is merging pull requests after all requirements have been
fulfilled.

## Area Experts

Area Experts are people with knowledge of specific components or technologies in the StoreBroker
domain. They are responsible for code reviews, issue triage, and providing their expertise to others. 

They have [write access](https://help.github.com/articles/repository-permission-levels-for-an-organization/)
to the StoreBroker repository which gives them the power to:

1. `git push` to all branches *except* `master`.
2. Merge pull requests to all branches *except* `master` (though this should not be common
   given that `master` is the only long-living branch.
3. Assign labels, milestones, and people to [issues](https://guides.github.com/features/issues/).

### Area Expert Responsibilities

If you are an Area Expert, you are expected to be actively involved in any development, design, or contributions in your area of expertise. 

If you are an Area Expert:

1. **DO** assign the correct labels
2. **DO** assign yourself to issues labeled with your area of expertise
3. **DO** code reviews for issues where you're assigned or in your areas of expertise.
4. **DO** reply to new issues and pull requests that are related to your area of expertise 
  (while reviewing PRs, leave your comment even if everything looks good - a simple
  "Looks good to me" or "LGTM" will suffice, so that we know someone has already taken a look at it).
5. **DO** make sure contributors are following the [contributor guidelines](../CONTRIBUTING.md).
6. **DO** ask people to resend a pull request, if it doesn't target `master`.
7. **DO** ensure that contributors [write Pester tests](../CONTRIBUTING.md#testing) for all
   new/changed functionality when possible.
8. **DO** ensure that contributors write documentation for all new-/changed functionality
9. **DO** encourage contributors to refer to issues in their pull request description
   (e.g. `Resolves issue #123`).
10. **DO** encourage contributors to create meaningful titles for all PRs. Edit title if necessary.
11. **DO** verify that all contributors are following the [Coding Guidelines](../CONTRIBUTING.md#coding-guidelines).
12. **DON'T** create new features, new designs, or change behaviors without having a public
    discussion on the design within its Issue.