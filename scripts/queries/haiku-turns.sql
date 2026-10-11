-- Measures assistant turns using Haiku models across project transcripts.
-- Haiku turns by model; Haiku 4.x is blocked, 5.5 allowed for reading work. Ref: rig#89, rig#183.
SET VARIABLE projects = coalesce(getvariable('projects'), getenv('HOME') || '/.claude/projects');

WITH all_rows AS (
    SELECT
        json_extract_string(json, '$.type') as type,
        json_extract_string(json, '$.message.model') as model,
        json_extract_string(json, '$.timestamp')::TIMESTAMP as ts,
        filename
    FROM read_ndjson_objects(getvariable('projects') || '/**/*.jsonl', filename=true)
)
SELECT
    count(*) FILTER (WHERE type = 'assistant' AND model ILIKE '%haiku%') AS haiku_turns,
    count(DISTINCT filename) FILTER (WHERE type = 'assistant' AND model ILIKE '%haiku%') AS transcript_files,
    min(ts) FILTER (WHERE type = 'assistant' AND model ILIKE '%haiku%') AS min_timestamp,
    max(ts) FILTER (WHERE type = 'assistant' AND model ILIKE '%haiku%') AS max_timestamp,
    min(ts) AS corpus_min_ts,
    max(ts) AS corpus_max_ts
FROM all_rows;
