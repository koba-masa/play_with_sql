DROP TABLE IF EXISTS comments;
CREATE TABLE comments(
    id SERIAL PRIMARY KEY
  , name VARCHAR(255)
  , childhood_name VARCHAR(255)
);

COMMENT ON TABLE comments IS 'コメントの検証';
COMMENT ON COLUMN comments.id IS 'ID';
COMMENT ON COLUMN comments.name IS '元服名';
COMMENT ON COLUMN comments.childhood_name IS '幼名';

INSERT INTO comments (name, childhood_name) VALUES
    ('織田信長', '吉法師')
  , ('豊臣秀吉', '日吉丸')
  , ('徳川家康', '竹千代')
;
