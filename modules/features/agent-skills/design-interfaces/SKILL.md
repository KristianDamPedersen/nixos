---
name: design-interfaces
description: Settle a feature's modules, interfaces and flows before agents implement it. Reuse-first; ends in committed stubs and a design note.
disable-model-invocation: true
---

# Design Interfaces

Settle the **shape** of a feature before agents write it: which modules it uses, the interface of each, and the flows between them. The user owns the shape; implementing agents own everything behind the interfaces.

**Reuse-first.** Most sessions end with "we use these existing abstractions this way, for this reason". A new abstraction earns its place by showing why no existing one fits.

**Stop at the interface.** Design a module's internals only when an internal decision changes its interface, such as an error defined out of existence.

## Conventions for the whole session

- Load `codebase-design` and use its terms exactly: module, interface, depth, seam, adapter, leverage, locality, deletion test.
- Read `GLOSSARY.md` if it exists and name modules in its terms. When a new term settles, or a seam decision is hard to reverse, surprising, and a real trade-off, hand it to `domain-modeling` (glossary entry or ADR).
- Run every user-facing step as `grilling` rounds: load `grilling` for the design tree, the frontier, and numbered questions with a recommended answer each. Facts are yours to find, through sub-agents; decisions are the user's.
- Check every proposed module, interface and flow against [RED-FLAGS.md](RED-FLAGS.md). A tripped flag becomes a question in the next round, citing the evidence. An untripped flag stays silent.

## 1. Gather evidence

Pick the source by what exists:

- **Prototype branch**: diff it against main. Pull out the interfaces it grew by accident, where knowledge crossed module lines, and the code that fought back. Cite this evidence in your questions.
- **No prototype**: read the area of main the feature touches.
- **Greenfield**: work from the conversation so far.

Done when you can list the feature's **capabilities**: one line each, naming something the code must do.

## 2. Inventory

Dispatch a sub-agent to map the existing modules, abstractions and conventions the feature could lean on: those in the touched area, plus project-wide conventions for errors, dependency injection, configuration and persistence. For each: its interface and where it is used.

Done when every capability has a candidate existing module or an explicit "nothing fits".

## 3. Sort

Put each capability in one bucket and present the sort as the first round:

- **Reuse**: an existing interface as-is. Record its real signatures and how the feature uses it, and why.
- **Extend**: an existing interface changes. List every affected call site and run the deletion test, so the user sees the cost and can choose a new module alongside instead.
- **New**: nothing fits. Say why each inventory candidate falls short.

If every capability is Reuse, confirm in that round, write the note (step 8) without stubs, and finish.

## 4. Module map

For each Extend and New module: the knowledge it hides behind its seam, and the modules it talks to. Ask the user to mark each module **central**, **uncertain**, or neither.

Done when every module has a hidden-knowledge line and a mark.

## 5. Interfaces

For each Extend and New module:

1. Ask the user for the **purpose sentence**: one sentence saying what the module does for its callers. The user writes it. If they struggle, the module is the wrong shape: say so and return to step 4.
2. For a central or uncertain module, run design-it-twice from `codebase-design` (its DESIGN-IT-TWICE.md), putting the purpose sentence in every brief. For other modules, write one draft.
3. The user picks, merges, or edits.

A drafted interface carries its signatures, interface comment, invariants, ordering constraints and error modes.

Done when every Extend and New module has an interface the user approved.

## 6. Flows

Draw each main path through the modules as a Mermaid sequence diagram, one participant per module. Look for knowledge crossing a seam, calls that skip a layer, and pass-through hops.

Done when every user-visible path from step 1 has an approved diagram.

## 7. Errors and test seams

For each error mode on an approved interface, decide one of: define it out of existence, mask it inside the module, aggregate it with others, or pass it to the caller. Passing it on needs a reason.

Then propose which interfaces are test seams, preferring the highest and fewest, each with a line on what a test there catches and what it misses. `to-spec` and `tdd` reuse this answer.

Done when every error mode has a decision and the user has approved the test seams.

## 8. Output

Summarise the whole design and get the user's confirmation. Then:

1. **Branch**: work on the feature branch. On the prototype path, cut it fresh from main and leave the prototype branch as it is.
2. **Stubs**: for each Extend and New module, write the interface in the project's language and layout: types, signatures, and interface comments opening with the purpose sentence, with bodies that throw "not implemented". Run the project's type-check or build; done when it passes. For a greenfield area with no language chosen, put pseudo-signatures in the note and skip stubs.
3. **Note**: write `docs/design/<feature>.md` from [NOTE-TEMPLATE.md](NOTE-TEMPLATE.md).
4. **Commit** stubs and note together as the branch's first commit: `design: interfaces for <feature>`.
5. Tell the user the next step: `/to-spec` reads the note.
