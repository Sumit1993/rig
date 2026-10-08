-- Turns, tool calls and background waits per agy run, from agy's own transcripts.
-- Rule: lane speed is turn count (5 s a turn), so this is the number to move. Ref: rig#167.
SET VARIABLE agy_brain = coalesce(getvariable('agy_brain'), getenv('HOME') || '/.gemini/antigravity-cli/brain');

WITH steps AS (
    SELECT
        regexp_extract(filename, 'brain/([^/]+)/', 1) AS conversation_id,
        type,
        TRY_CAST(created_at AS TIMESTAMP) AS ts,
        CAST(content AS VARCHAR) AS content,
        CAST(tool_calls AS JSON) AS tool_calls
    FROM read_json(getvariable('agy_brain') || '/*/.system_generated/logs/transcript.jsonl',
                   format = 'newline_delimited', union_by_name = true, filename = true)
),
calls AS (
    SELECT conversation_id, json_extract_string(c, '$.name') AS tool
    FROM steps, unnest(CAST(tool_calls AS JSON[])) AS t(c)
    WHERE type = 'PLANNER_RESPONSE' AND tool_calls IS NOT NULL
),
runs AS (
    SELECT
        conversation_id,
        min(ts) AS started,
        round(epoch(max(ts) - min(ts)) / 60, 1) AS minutes,
        count(*) FILTER (WHERE type = 'PLANNER_RESPONSE') AS turns,
        max(json_array_length(tool_calls)) FILTER (WHERE type = 'PLANNER_RESPONSE') AS max_calls_per_turn,
        count(*) FILTER (WHERE content LIKE '%running as a background task%') AS backgrounded,
        any_value(regexp_extract(content, 'Model Selection` from \S+ to (.+?)\. ', 1)) FILTER (WHERE type = 'USER_INPUT') AS model
    FROM steps
    GROUP BY conversation_id
)
SELECT
    r.started, r.conversation_id[1:8] AS conv, r.model, r.minutes, r.turns, r.max_calls_per_turn,
    count(c.tool) AS calls,
    count(c.tool) FILTER (WHERE c.tool = 'view_file') AS view_file,
    count(c.tool) FILTER (WHERE c.tool = 'manage_task') AS manage_task,
    r.backgrounded
FROM runs r LEFT JOIN calls c USING (conversation_id)
WHERE getvariable('since') IS NULL OR getvariable('since') = '' OR r.started >= CAST(getvariable('since') AS TIMESTAMP)
GROUP BY ALL
ORDER BY r.started DESC
LIMIT 40;
