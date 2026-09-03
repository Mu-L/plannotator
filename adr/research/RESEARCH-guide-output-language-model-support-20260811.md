# Research: output language support for Guided Review (issue #1265)

Date: 2026-08-11
Scope: can Plannotator ship a first-class output language setting for Guided Review, given that the guide job runs on whatever agent CLI and model the user happens to have?
Status: research only, no code changes.

## Executive summary

Yes, but as a prompt-only, best-effort setting with an honest disclaimer, not as a capability-gated feature.

Four things drive that conclusion.

1. **The task is easy by structured-output standards.** Plannotator's guide schema (`GUIDE_SCHEMA_JSON` in `packages/server/guide/guide-review.ts`) has no enums, no numbers, no severity labels, no categories. Every value is either free prose (`title`, `intent`, `sections[].title`, `sections[].overview`, `diffs[].summary`) or an exact repo-relative file path copied from a list the prompt supplies (`diffs[].file`, `unplacedFiles[]`). The keys are fixed by the schema on Claude and Codex, and restated in prose for the marker engines. There is nothing in the schema a model could plausibly translate except the prose fields we actually want translated. This is the single most important fact: the usual "the model translated my enum values" failure mode has no surface here.

2. **Frontier models handle this reliably; the risk is concentrated in the small and local tail.** Claude, GPT-5.x, and Gemini 3.x all sit at 92 to 98 percent of their English performance in Spanish, Portuguese, French, Italian, German, and only fall off in genuinely low-resource languages. The gap between tiers is real and measurable: Anthropic's own published table shows Sonnet 4.5 at 91.1 percent of English performance in Swahili while Haiku 4.5 drops to 78.3 percent, and Yoruba goes 79.7 percent versus 52.7 percent. Small local models are worse again, and they fail on structure before they fail on language.

3. **The dominant failure mode is drift, not refusal.** Published work and product bug trackers agree: a model told to write in French starts in French and slides back toward English (or, on DeepSeek, toward Chinese) as the output gets longer and more technical. A guide is exactly the shape of output that provokes this: several hundred words of prose interleaved with English identifiers, English file paths, and English diff content. Expect partially-English guides, not English guides.

4. **Every comparable product ships this as a plain setting with no capability gating, and every one of them has open bugs about it.** GitHub Copilot has `github.copilot.chat.localeOverride`, JetBrains AI Assistant has a "Receive AI Assistant chat responses in a custom language" field, Cline has `preferredLanguage`, Codex has a `localeOverride`. All four have open issues where some subsystem ignores the setting. None of them gate the setting on the model. None of them publish a supported-language list. That is the industry norm, and it is the norm because the alternative (maintaining a model-by-model language matrix) is unmaintainable.

**Recommended shape:** ship it as prompt-only with no gating (Option A below). Put the language instruction in three places (the methodology prompt, the repair prompt, and the marker output contract), explicitly scope it to the five prose fields, explicitly exclude file paths and code identifiers, and say in the settings UI that quality depends on the model. Do not build a supported-language dropdown. Do not gate by provider. Reserve one small piece of engineering for the thing that actually breaks: the repair path, which currently re-prompts with framing that says nothing about language and will happily produce an English guide from a French one.

## Grounding: what the guide job actually asks for

From `/Users/ramos/plannotator/plannotator/packages/server/guide/guide-review.ts`:

- `GUIDE_SCHEMA_JSON` (lines 31 to 67), `additionalProperties: false` throughout:
  `{ title, intent, sections: [{ title, overview, diffs: [{ file, summary }] }], unplacedFiles: [string] }`
- No enum, no numeric field, no severity or category or ordering label anywhere. Section ordering semantics are carried by array position only.
- Prose fields: `title`, `intent`, `sections[].title`, `sections[].overview`, `diffs[].summary`. Five fields, all free text.
- Structural fields: `diffs[].file` and `unplacedFiles[]`, both exact paths validated against the launch-time changed-file set by `validateGuideOutput` (line 969).
- `GUIDE_REVIEW_PROMPT` (lines 69 to 264) already encodes prose constraints in natural language: 2 to 6 sections, overview 2 to 6 sentences, no em-dashes, no emoji.

Enforcement splits into two classes, which matters for the recommendation:

- **Schema-enforced engines.** Claude via `--json-schema`, Codex via `--output-schema` pointing at a materialized schema file. Keys are guaranteed. Only the prose values are free.
- **Prompt-enforced engines (the "marker" engines).** Cursor, OpenCode, Pi, Copilot. No schema flag exists on those CLIs, so `buildGuideMarkerOutputContract` (line 476) restates the schema in prose plus a worked JSON example, wrapped in nonce-tagged markers. These are the ones where a language instruction could in principle bleed into the keys, because the keys are themselves prose in the prompt.

There is currently **no per-provider capability gate and no model tier concept** anywhere in the guide path. Availability is binary-presence only (`agent-jobs.ts`, roughly lines 189 to 212). Adding one for language would be new architecture with no precedent in the codebase, which is a point in favour of the prompt-only option.

Two existing details are directly relevant risks:

- **The repair chain re-prompts.** `buildGuideRepairFraming()` (545), `buildGuideRepairPrompt()` (550), `composeGuideMarkerRepairPrompt()` (558). A repair job forces effort to `low`/`minimal` and may fall back to a *different* engine than the one that failed (`review.ts`, roughly lines 990 to 1027). If the language instruction is not carried into the repair framing, a French guide that failed to parse comes back English.
- **The guide defaults are deliberately low-effort.** `DEFAULT_GUIDE_CLAUDE_EFFORT = 'low'`, `DEFAULT_GUIDE_CODEX_REASONING = 'low'` (`packages/ui/hooks/useAgentSettings.ts`), and `buildCommand` defaults Claude to `sonnet`. Low reasoning effort is the regime where instruction adherence is weakest, so the setting will be exercised under the least favourable conditions by default.

## Findings by model class

### Frontier API models

**Claude.** Anthropic publishes a per-language table of zero-shot chain-of-thought scores as a percentage of English performance, and separately documents the exact pattern this feature needs. Sonnet 4.5: Spanish 98.2, Portuguese (BR) 97.8, Italian 97.9, French 97.5, Indonesian 97.3, German 97.0, Arabic 97.2, Chinese (Simplified) 96.9, Japanese 96.8, Korean 96.7, Hindi 96.7, Bengali 95.4, Swahili 91.1, Yoruba 79.7. The docs say plainly: "Claude infers the response language from the conversation, but for production applications you should state the target language explicitly. The most reliable place to do this is the system prompt." And: "If your application lets users pick a language at runtime, interpolate that choice into the system prompt rather than relying on Claude to infer it." That is a direct endorsement of the prompt-only design.
Source: https://platform.claude.com/docs/en/build-with-claude/multilingual-support

**GPT-5 family.** OpenAI's system card evaluates on human-translated MMLU across 13 languages (Arabic, Bengali, Chinese Simplified, French, German, Hindi, Indonesian, Italian, Japanese, Korean, Portuguese BR, Spanish, Swahili, Yoruba). The headline finding, and it is worth knowing before promising anything: multilingual performance was roughly flat versus the previous generation, with GPT-5-main marginally *weaker* than o3-high across all 13 languages and GPT-5-thinking about on par. Multilingual is not where the recent frontier gains landed.
Sources: https://cdn.openai.com/gpt-5-system-card.pdf, https://slator.com/openai-launches-gpt5/, https://github.com/openai/simple-evals/blob/main/multilingual_mmlu_benchmark_results.md

**Gemini.** Tops the Global-MMLU-Lite leaderboard (Gemini 3.1 Pro Preview at 93.2 percent, Gemini 3 Pro Preview high at 92.2 percent, with Claude Opus 4.6 at 92.2 percent), across 16 languages including Yoruba, Swahili, and Burmese. Gemini also scores well on cross-lingual constraint adherence specifically: XIFBench found Gemini-2.0-Flash "forming nearly regular polygons across languages," meaning near-identical constraint compliance regardless of language, where mid-capacity models degraded visibly.
Sources: https://artificialanalysis.ai/evaluations/global-mmlu-lite, https://cohere.com/research/globalmmlu, https://arxiv.org/abs/2503.07539

**Practical read for frontier models.** For French, Spanish, German, Portuguese, Italian, and the major Asian languages, all three frontier families will produce good guide prose. The failure to plan for is not "it cannot do it," it is drift over the length of the output, covered below.

### Mid-tier and small models

Degradation here is measurable and steep at the low-resource end, mild at the high-resource end. The cleanest published comparison is Anthropic's own Sonnet 4.5 versus Haiku 4.5 table (same benchmark, same methodology, two tiers of one family):

| Language | Sonnet 4.5 | Haiku 4.5 | Delta |
| --- | --- | --- | --- |
| Spanish | 98.2 | 96.4 | 1.8 |
| French | 97.5 | 95.7 | 1.8 |
| German | 97.0 | 94.3 | 2.7 |
| Japanese | 96.8 | 93.5 | 3.3 |
| Korean | 96.7 | 93.3 | 3.4 |
| Bengali | 95.4 | 90.4 | 5.0 |
| Swahili | 91.1 | 78.3 | 12.8 |
| Yoruba | 79.7 | 52.7 | 27.0 |

The shape is the important part: for Western European languages the tier gap is under 3 points and does not matter for guide prose. For low-resource languages the small tier collapses. Plannotator's guide defaults (Sonnet, low effort) sit safely in the first regime for the languages users are most likely to request.

XIFBench generalizes this beyond one vendor: higher-capacity models show stable cross-lingual constraint adherence, while mid- and low-capacity models (it names Qwen-2.5-72B and GLM-4-9B) "exhibit progressive degradation in polygon size and regularity as language resources decrease." It also found that *format and numerical constraints are the most resilient to language variation*, while style and situation constraints are the most sensitive. Applied here: "emit this JSON shape" survives the language switch better than "write 2 to 6 sentences in this voice."
Source: https://arxiv.org/abs/2503.07539

MMLU-ProX, across 29 languages and 36 models, puts a number on the high-resource to low-resource spread: gaps of up to 24.3 percent.
Source: https://arxiv.org/abs/2503.10497

### Local and open-weight models

This is where the honest answer is "it depends on the model, and structure fails before language does."

**Genuinely multilingual:**

- **Qwen 3.** Trained on roughly 36 trillion tokens covering 119 languages and dialects, up from 29 in Qwen 2.5. The most broadly multilingual open family available, and the best default recommendation for a non-English guide on local hardware.
  Sources: https://qwenlm.github.io/blog/qwen3/, https://arxiv.org/abs/2505.09388
- **Mistral.** Mistral Large 3 is trained natively on 40-plus languages with explicit emphasis on European languages (French, German, Spanish, Italian, Portuguese). For the exact languages issue #1265 names, this is a strong fit. Ministral 3 also currently ranks as the top open model on Multilingual MMLU per llm-stats.
  Sources: https://huggingface.co/mistralai/Mistral-Large-3-675B-Base-2512, https://llm-stats.com/benchmarks/multilingual-mmlu

**Narrower than advertised:**

- **Llama 4.** The model card officially supports 12 languages: Arabic, English, French, German, Hindi, Indonesian, Italian, Portuguese, Spanish, Tagalog, Thai, Vietnamese. Pre-training covered 200 languages but Meta only *supports* those 12. Notably absent from the supported list: Japanese, Korean, Chinese, Dutch, Polish, Russian. A user asking for a Japanese guide from Llama 4 is outside the vendor's own support envelope.
  Source: https://github.com/meta-llama/llama-models/blob/main/models/llama4/MODEL_CARD.md

**Actively risky:**

- **DeepSeek.** The V3 technical report acknowledges language mixing, and the repository has multiple long-lived user reports of unprompted switching to Chinese in English conversations, persisting even after the user asks it to switch back. Research on multilingual reasoning transfer also notes DeepSeek-R1's English bias and language mixing during chain-of-thought, and that forcing target-language reasoning typically *reduces* accuracy. For a feature whose whole point is "stay in the requested language," DeepSeek is the worst-behaved family in the set.
  Sources: https://arxiv.org/pdf/2412.19437, https://github.com/deepseek-ai/DeepSeek-V3/issues/1226, https://github.com/deepseek-ai/DeepSeek-V3/issues/1463, https://github.com/deepseek-ai/DeepSeek-V3/issues/1481

**Language rank order that holds across every source reviewed:** Spanish, French, Portuguese, Italian, German are safe on essentially any model that claims multilinguality. Chinese, Japanese, Korean, Arabic, Hindi are safe on frontier and on Qwen, patchy on Llama 4 and small local models. Everything else (Swahili, Yoruba, Bengali beyond frontier, minority European languages) is genuinely unreliable below the frontier tier.

**The structural caveat that matters more than any of the above.** Small local models fail JSON before they fail French. Measured figures:

- Mistral-7B-Instruct-v0.3 under free-text JSON prompting: 74.3 to 78.6 percent first-pass validity, with 18.6 to 21.4 percent persistent parse or schema failures even after retry. https://doi.org/10.3390/healthcare14142150
- Llama-3.1-8B: schema validity 68.7 percent unconstrained, 100 percent with constrained decoding, but semantic success stayed at 36.0 percent either way. https://arxiv.org/html/2607.18261v1
- Below 4B parameters, "extraction accuracy is dominated by structured output compliance failures," with 35 to 47 percent schema validation failure rates. https://arxiv.org/html/2605.02363v1
- Quantization interacts badly: Q4_K_M is widely reported to degrade structured output silently while looking fine in chat, with Q6_K treated as the practical floor for agentic work. This is community consensus rather than a published study, so treat it as a hypothesis, but it matches the observed pattern. https://github.com/anomalyco/opencode/issues/5694

Plannotator's marker engines (Cursor, OpenCode, Pi, Copilot) are exactly the prompt-enforced path where a small local model behind OpenCode has to hold both the JSON contract and the language instruction with no schema enforcement at all. That is the worst cell in the matrix. It is also already the worst cell today, before any language feature, and `repairGuideJsonText` plus `validateGuideOutput` already exist to absorb it.

## Structured output and language: how they interact

Three findings, in decreasing order of relevance.

**1. Language drift is a decoding-level phenomenon that gets worse with output length.** The clearest characterization is "Language Drift in Multilingual Retrieval-Augmented Generation" (AAAI). Its central observation: "the generation begins in the target language but progressively deviates into English." The cause is not comprehension failure but "decoder-level collapse, where dominant token distributions and high-frequency English patterns dominate the intended generation language." English functions as "a semantic attractor," and is simultaneously "the strongest interference source and the most frequent fallback language." The effect is most pronounced during reasoning-intensive decoding.
Source: https://arxiv.org/abs/2511.09984 (also https://ojs.aaai.org/index.php/AAAI/article/view/40417)

Applied to a guide: the input is a diff full of English identifiers, English commit subjects, and English file paths, and the output is several hundred words of prose. That is a near-textbook setup for drift. Expect `title` and `intent` to come back correctly localized and later `sections[].overview` and `diffs[].summary` entries to drift toward English, especially in longer guides with 5 or 6 sections.

**2. Constrained decoding costs some correctness, but there is no evidence it specifically damages language adherence.** JSONSchemaBench (10K real-world schemas) is the reference work on whether constrained decoding hurts output quality; the "constraint tax" line of work quantifies a validity-versus-correctness tradeoff on small models. The mechanism proposed is that constrained decoding can force non-canonical tokenizations the model rarely saw in training. That mechanism would in principle apply to non-Latin scripts more than to Latin ones (more tokens per character, more opportunity for an unusual path), but no source found makes that claim directly, so it should be treated as an untested hypothesis rather than a finding.
Sources: https://arxiv.org/abs/2501.10868, https://openreview.net/forum?id=FKOaJqKoio, https://arxiv.org/pdf/2605.26128

The practically relevant point is that Plannotator's schema constrains *structure*, not *content*: `additionalProperties: false` with five `type: string` prose fields means the constraint is inactive inside the strings where the language lives. Constrained decoding cannot degrade language quality in a field it does not constrain.

**3. Format constraints survive language switches better than style constraints.** XIFBench again: format and numerical constraints are resilient across languages, style and situation constraints are not. Concretely, "return this JSON shape" and "copy these exact paths" will hold when the language changes. "2 to 6 sentences," "no em-dashes," "confident and direct voice" are the instructions most likely to slip. `GUIDE_REVIEW_PROMPT` currently encodes several of these as style constraints, so a non-English guide is more likely to violate the sentence-count and punctuation rules than to violate the schema. The no-em-dash rule in particular is worth a second look: typographic conventions differ by language, and French in particular uses spaced dashes and guillemets natively.

**4. There is no vendor documentation warning against mixing schema-constrained output with non-English prose.** OpenAI's, Google's, and Anthropic's structured-output docs are silent on the interaction, which is weak evidence that it is not a known problem class. Anthropic's multilingual page actively recommends the system-prompt approach without any structured-output caveat.
Sources: https://developers.openai.com/api/docs/guides/structured-outputs, https://ai.google.dev/gemini-api/docs/structured-output, https://platform.claude.com/docs/en/build-with-claude/multilingual-support

## Competitor survey

| Product | Setting | Scope and wording | Known problems |
| --- | --- | --- | --- |
| GitHub Copilot (VS Code) | `github.copilot.chat.localeOverride` | Default `"auto"`, follows the VS Code display language. Takes a locale code (`ja`, `fr`, `zh-CN`). Affects chat, edit, terminal, and commit message generation. | Inconsistent adherence (issue 651: sometimes responds in the configured language, sometimes English). Slash-command-only quick chat ignores it entirely (issue 1354). Users want per-surface language control (issue 6970). |
| JetBrains AI Assistant | "Receive AI Assistant chat responses in a custom language", Settings > Tools > AI Assistant > Natural Language | Free-text field: "specify the language in which you want to receive chat responses." No supported-language list, no reliability claims. | Documented scoping caveat: enabling it updates the active chat and new chats, but "existing ones will remain in a language that was selected previously." |
| Cline | `preferredLanguage` | Read by the main task system and injected into the system prompt. | Commit message generation uses hardcoded English prompts and ignores the setting (issues 7055, 8096). Classic case of one subsystem missing the plumbing. |
| Codex | `localeOverride` in `[desktop]` of `~/.codex/config.toml` | UI locale, not agent output language. | Setting changes config but the UI stays English (issue 23815). Separately, there is an open request for a `reasoning_language` config key because agent reasoning is always English regardless of input language (issue 8572), plus a general i18n request (issue 3466) and reports of unrequested language switching (issue 10433). |
| Cursor | None | Rules docs contain no example about response language; the closest is a tone rule ("Please reply in a concise style"). Users set it ad hoc in `.cursor/rules` or `AGENTS.md`. | Not applicable. |
| Gemini CLI | `language` in `~/.gemini/settings.json` | UI localization, not model output language. | Setting is honoured in config but the CLI stays English (issue 2487). Separate reports of mixed-alphabet output (issue 13715) and answering in multiple languages when Spanish was requested (issue 4072). |
| Claude Code | No documented `language` key | Neither the official settings reference nor the changelog documents a response-language setting. Third-party guides recommend putting "always converse in Japanese" in `CLAUDE.md`. A widely-repeated third-party claim that v2.1.0 added a `language` setting could not be verified against official docs; treat as unconfirmed. | Multiple open bugs: switches Korean to Japanese mid-response (issue 24941, marked duplicate), switches Traditional Chinese to Korean or Japanese (issue 57212), ignores an explicit Traditional Chinese instruction in `CLAUDE.md` and answers in Japanese (issue 46846). |

Sources: https://github.com/microsoft/vscode-copilot-release/issues/651, https://github.com/microsoft/vscode-copilot-release/issues/927, https://github.com/microsoft/vscode-copilot-release/issues/1354, https://github.com/microsoft/vscode-copilot-release/issues/6970, https://www.jetbrains.com/help/ai-assistant/customize-ai-chat.html, https://youtrack.jetbrains.com/articles/SUPPORT-A-873/How-to-set-up-preferred-language-for-JetBrains-AI-Assistant, https://github.com/cline/cline/issues/7055, https://github.com/cline/cline/issues/8096, https://github.com/openai/codex/issues/23815, https://github.com/openai/codex/issues/8572, https://github.com/openai/codex/issues/3466, https://cursor.com/docs/rules, https://github.com/google-gemini/gemini-cli/issues/2487, https://github.com/google-gemini/gemini-cli/issues/13715, https://github.com/anthropics/claude-code/issues/24941, https://github.com/anthropics/claude-code/issues/57212, https://github.com/anthropics/claude-code/issues/46846

**Four lessons that transfer directly.**

1. **Nobody gates on model capability.** Not one of these products checks which model is in use before offering the setting. Building a capability gate would make Plannotator the outlier, and it would need per-model data that no vendor publishes in a machine-readable form.
2. **Nobody publishes a supported-language list.** Free-text or locale-code input, no dropdown of blessed languages. A supported-language tier list would be a maintenance burden with no competitor precedent and no stable source of truth to derive it from.
3. **The recurring bug is a subsystem that forgot the setting.** Cline's commit-message generator, Copilot's slash-command quick chat, Codex's reasoning stream. Plannotator's exact analogue is the **repair prompt path**. That is where to spend the engineering.
4. **The recurring bug class after that is mid-output switching**, present even in Claude Code with a frontier model. This is the language drift finding showing up in production. It cannot be fully prevented by prompting, which is why the disclaimer matters.

## Options

### Option A: prompt-only, no gating, best-effort disclaimer (recommended)

Add an output language setting alongside the existing per-engine guide settings in `useAgentSettings.ts`. Free-text or a short unvalidated suggestion list, defaulting to unset (current behaviour, English). When set, inject one instruction into all three prompt layers.

Implementation surface, all in `packages/server/guide/guide-review.ts` plus one settings field:

- `GUIDE_REVIEW_PROMPT`: append a language block when the option is present.
- `buildGuideMarkerOutputContract(nonce)`: same instruction, restated, because these engines have no schema backstop and are the most likely to drift.
- `buildGuideRepairFraming()` and `composeGuideMarkerRepairPrompt()`: carry the language through. This is the Cline commit-message bug, pre-empted. Note that repair may switch engines, so the language has to be threaded through `config.repairOf` handling in `review.ts`, not just captured in a closure.
- Persist the language alongside the guide in `guide-store.ts` so a saved guide reloaded later is not confusing, and so a repair launched after the fact uses the same language.

The instruction itself needs to be explicit about the boundary. Something with this shape:

> Write all prose in {language}: the guide title, the intent line, every section title, every section overview, and every file summary. Keep everything else exactly as specified: JSON keys stay in English, and file paths, identifiers, function names, type names, and quoted code stay verbatim in their original form. Do not translate a path or a symbol. Stay in {language} for the entire response, including the last section. Do not drift back to English partway through.

That last sentence is doing real work: it is a direct counter to the documented drift pattern, and it is cheap.

Two further prompt notes:

- The existing "no em-dashes" rule should be reviewed for non-English output. Typographic norms differ, and enforcing an English convention on French or German prose is the kind of style constraint XIFBench found to be least robust across languages anyway.
- Consider whether the "2 to 6 sentences" overview constraint should be relaxed or restated when a language is set, for the same reason.

**Cost:** small. One settings field, one prompt block repeated in three or four places, one persistence field.
**Risk:** partially-English guides on weak models and long outputs. Mitigated by the disclaimer, not by code.
**Precedent:** matches every product surveyed.

### Option B: prompt-only plus a post-hoc language check and one automatic retry

Everything in Option A, plus a cheap heuristic language detector run over the concatenated prose fields after `validateGuideOutput`. If a meaningful fraction of the prose is not in the requested language, relaunch once with a stronger instruction, then surface the result either way with a badge if it is still mixed.

**Cost:** medium. A detector dependency or a hand-rolled heuristic, plus retry orchestration that has to interact with the existing repair-job machinery (which already relaunches, already forces low effort, and already may switch engines). Two independent retry paths in the same code is a real complexity increase.
**Risk:** false positives are the killer. Guide prose is unavoidably dense with English identifiers, English file paths, and English type names quoted inline. Any off-the-shelf detector will call correct French guide prose "mixed." Tuning that threshold is a research project in itself.
**Verdict:** the failure mode being solved (partial drift) is exactly the one this cannot distinguish from correct behaviour. Not worth it now. Revisit only if user reports show drift is common in practice.

### Option C: capability-gated, with a supported-language tier list per provider

Add a capability descriptor to `MARKER_ENGINES` and the schema-engine paths, plus a curated language tier list, and hide or warn on the setting for combinations judged unreliable.

**Cost:** high, and permanent. No `supportsSchema`-style capability field exists anywhere in the guide path today, so this is new architecture. The data does not exist either: the server sees an engine binary, not a model. OpenCode can be pointed at literally any model including local ones, so the server genuinely cannot know whether the model behind `opencode` is Qwen 3 (119 languages) or a 4-bit 7B (35 to 47 percent schema failure before language is even considered). The tier list would need per-model-per-language maintenance against vendor claims that are inconsistent, unbenchmarked, and change every release.
**Risk:** gating on a proxy the server cannot observe produces both false denials (blocking a user with a perfectly capable local Qwen) and false confidence (allowing a quantized model that will fail).
**Verdict:** not defensible. The information needed to gate correctly is not available at the gating point.

## Recommendation

**Option A.** Ship it prompt-only, ungated, with an honest disclaimer, and spend the saved effort on threading the language through the repair path and on the drift-resistant prompt wording.

The reasoning in one line: the schema has no translatable structural values, so the hard part of "structured output in another language" does not exist here; the remaining risk is drift, which no competitor has solved with gating either, and which a clear disclaimer handles better than a wrong capability check.

### Suggested wording

For the settings UI, following the register the surveyed products use (plain, no promises, no supported-language list):

> **Output language.** Write guide titles, overviews, and file summaries in this language. File paths, code identifiers, and the guide's structure stay unchanged. Results depend on the model you run the guide with: capable models handle widely spoken languages well, and smaller or local models may fall back to English partway through.

Shorter alternative for a tooltip:

> Guide prose is written in this language. Quality depends on the model. Paths and identifiers are never translated.

Both avoid the two traps: they do not claim a supported-language set, and they name the specific failure the user will actually see (falling back to English partway through) rather than a vague "results may vary."

### What to explicitly not build

- A supported-language dropdown or tier list. No competitor has one, and there is no stable source of truth to derive it from.
- Per-provider gating. The server cannot observe the model behind OpenCode, Cursor, or Pi.
- A separate retry loop for language. The repair machinery already exists; a second retry path competing with it is a source of bugs, and the detection problem is unsolved.

### If the maintainer wants evidence before shipping

The cheapest useful validation is a handful of manual runs on one real diff, holding everything else fixed:

1. Claude (Sonnet, effort `low`, which is the current guide default) in French and in Japanese, on a diff large enough to produce 5 or 6 sections. Checking specifically whether the *later* sections drift, since that is where the drift literature predicts it.
2. The same guide through a marker engine (OpenCode against a local Qwen 3, and against something smaller) to confirm the JSON contract survives the added instruction. If the marker output contract stops parsing when a language instruction is added, that is the one result that would change the recommendation, because it would mean the language instruction is competing with the schema restatement for the model's attention.
3. One run where the diff itself contains non-English comments or identifiers, to confirm the "do not translate identifiers" instruction holds in the direction that matters.

Three runs, one afternoon, and they cover the only two questions the literature leaves genuinely open for this specific schema.

## Sources

Vendor and product documentation:
- https://platform.claude.com/docs/en/build-with-claude/multilingual-support
- https://cdn.openai.com/gpt-5-system-card.pdf
- https://github.com/openai/simple-evals/blob/main/multilingual_mmlu_benchmark_results.md
- https://developers.openai.com/api/docs/guides/structured-outputs
- https://ai.google.dev/gemini-api/docs/structured-output
- https://github.com/meta-llama/llama-models/blob/main/models/llama4/MODEL_CARD.md
- https://qwenlm.github.io/blog/qwen3/
- https://huggingface.co/mistralai/Mistral-Large-3-675B-Base-2512
- https://www.jetbrains.com/help/ai-assistant/customize-ai-chat.html
- https://youtrack.jetbrains.com/articles/SUPPORT-A-873/How-to-set-up-preferred-language-for-JetBrains-AI-Assistant
- https://cursor.com/docs/rules
- https://code.visualstudio.com/docs/agent-customization/language-models

Benchmarks and leaderboards:
- https://artificialanalysis.ai/evaluations/global-mmlu-lite
- https://cohere.com/research/globalmmlu
- https://llm-stats.com/benchmarks/multilingual-mmlu
- https://arxiv.org/abs/2503.10497 (MMLU-ProX)
- https://arxiv.org/abs/2503.07539 (XIFBench)
- https://arxiv.org/abs/2501.10868 (JSONSchemaBench)

Research papers:
- https://arxiv.org/abs/2511.09984 (language drift, AAAI)
- https://ojs.aaai.org/index.php/AAAI/article/view/40417
- https://arxiv.org/pdf/2605.26128 (constraint tax)
- https://arxiv.org/html/2605.02363v1 (structured output reliability in small models)
- https://arxiv.org/html/2607.18261v1 (semantic reliability of schema-constrained agents)
- https://doi.org/10.3390/healthcare14142150 (local 7B to 8B schema stability)
- https://arxiv.org/pdf/2412.19437 (DeepSeek-V3 technical report)
- https://arxiv.org/abs/2505.09388 (Qwen3 technical report)

Product issue trackers:
- https://github.com/microsoft/vscode-copilot-release/issues/651
- https://github.com/microsoft/vscode-copilot-release/issues/927
- https://github.com/microsoft/vscode-copilot-release/issues/1354
- https://github.com/microsoft/vscode-copilot-release/issues/6970
- https://github.com/cline/cline/issues/7055
- https://github.com/cline/cline/issues/8096
- https://github.com/openai/codex/issues/23815
- https://github.com/openai/codex/issues/8572
- https://github.com/openai/codex/issues/3466
- https://github.com/openai/codex/issues/10433
- https://github.com/google-gemini/gemini-cli/issues/2487
- https://github.com/google-gemini/gemini-cli/issues/13715
- https://github.com/google-gemini/gemini-cli/issues/4072
- https://github.com/anthropics/claude-code/issues/24941
- https://github.com/anthropics/claude-code/issues/57212
- https://github.com/anthropics/claude-code/issues/46846
- https://github.com/deepseek-ai/DeepSeek-V3/issues/1226
- https://github.com/deepseek-ai/DeepSeek-V3/issues/1463
- https://github.com/deepseek-ai/DeepSeek-V3/issues/1481
- https://github.com/anomalyco/opencode/issues/5694

Codebase (read only, unmodified):
- /Users/ramos/plannotator/plannotator/packages/server/guide/guide-review.ts
- /Users/ramos/plannotator/plannotator/packages/server/review.ts
- /Users/ramos/plannotator/plannotator/packages/server/agent-jobs.ts
- /Users/ramos/plannotator/plannotator/packages/server/marker-review.ts
- /Users/ramos/plannotator/plannotator/packages/shared/guide.ts
- /Users/ramos/plannotator/plannotator/packages/shared/guide-store.ts
- /Users/ramos/plannotator/plannotator/packages/ui/hooks/useAgentSettings.ts

### Confidence notes

- The Anthropic per-language table, the Llama 4 supported-language list, the Qwen 3 language count, the Copilot and JetBrains and Cline settings, and the issue-tracker reports are all from primary sources and are high confidence.
- The Global-MMLU-Lite leaderboard numbers are a live leaderboard and will move.
- Several open-model comparison figures surfaced only through SEO-style aggregator blogs and were not used except where a primary source corroborated them.
- The claim that Claude Code v2.1.0 added a `language` setting appears in third-party guides but could not be found in the official settings reference or changelog. Treat as unconfirmed.
- The quantization-degrades-structured-output claim is community consensus, not a published study.
- No source was found that directly tests schema-constrained decoding against non-English prose fields. The conclusion that the interaction is benign here rests on the structural argument (the schema constrains keys and shape, not string contents) rather than on direct evidence.
