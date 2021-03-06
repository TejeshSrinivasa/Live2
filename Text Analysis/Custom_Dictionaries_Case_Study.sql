-- ##############################################################
-- ##############################################################
-- ##############################################################
-- ##########  CUSTOM DICTIONARIES COUNTRY EXAMPLE ##############
-- ##############################################################
-- ##############################################################
-- ##############################################################

-- needed for using TA schema for new analytic view
-- not really needed anymore
-- grant access
grant select on schema TA to _SYS_REPO with grant option;

-- Create file "LIVE2.hdbtextdict"
<?xml version="1.0" encoding="UTF-8"?>
<dictionary xmlns="http://www.sap.com/ta/4.0">
	<entity_category name="LIVE 2 COUNTRY">
		<entity_name standard_form="Afghanistan">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="Canada">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="China">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="Georgia">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="Germany">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="Iran">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="Iraq">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="Ireland">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="Israel">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="Italy">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="Kenya">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="N.Korea">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="Pakistan">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="Panama">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="Peru">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="Russia">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="Spain">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="Ukraine">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="USA">
			<variant name="U.S." type="ABBREV" />
			<variant name="US" />
			<variant name="AMERICA" />
			<variant name="UNITED STATES" />
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="USSR">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="Venezuela">
			<variant_generation type="standard" language="english" />
		</entity_name>
		<entity_name standard_form="Vietnam">
			<variant_generation type="standard" language="english" />
		</entity_name>
	</entity_category>
</dictionary>

-- LIVE2.hdbtextconfig
<string-list-value>sap.hana.ta.config::LIVE2.hdbtextdict</string-list-value>

-- as we need an "old" and "new" index, let's replicate our tweets table
-- we need the table for later on ... so, create duplicate table
DROP TABLE "LIVE2"."Tweets_for_CD" CASCADE;
CREATE COLUMN TABLE "LIVE2"."Tweets_for_CD" ("tweetId" INTEGER CS_INT NOT NULL ,
	 "memberId" INTEGER CS_INT,
	 "tweetDate" LONGDATE CS_LONGDATE,
	 "tweetContent" NVARCHAR(500),
	 PRIMARY KEY ("tweetId")) UNLOAD PRIORITY 5 AUTO MERGE;

-- don't forget to insert some data into it
INSERT INTO "LIVE2"."Tweets_for_CD" 
SELECT * FROM "LIVE2"."Tweets";

-- create the a new sentiment analysis index table on the additional new table
DROP FULLTEXT INDEX "LIVE2"."MYINDEX_VOC_WITH_CD";
CREATE FULLTEXT INDEX myindex_voc_with_cd ON "LIVE2"."Tweets_for_CD" ("tweetContent")
CONFIGURATION 'sap.hana.ta.config::LIVE2'
TEXT ANALYSIS ON;

-- look at the normalized data
SELECT * FROM "LIVE2"."$TA_MYINDEX_VOC_WITH_CD"
WHERE "TA_TYPE" = 'LIVE 2 COUNTRY';

-- looks good ? 
-- but there is a problem with "us" (the pronoun) and "US" (the country) :-(

-- the following statement is kinda what we were expecting, using the base dictionary
SELECT TOKEN, SUM(COUNT) as COUNT FROM
(SELECT CASE WHEN UPPER(TA_TOKEN) IN ('US','U.S.','AMERICA','USA','UNITED STATES')
THEN ('US') ELSE (UPPER(TA_TOKEN)) END AS TOKEN , COUNT(*) AS COUNT
FROM "LIVE2"."$TA_MYINDEX_VOC" 
where TA_TYPE = 'COUNTRY' 
GROUP BY TA_TOKEN ORDER BY COUNT DESC)
GROUP BY TOKEN ORDER BY COUNT DESC;

-- this is what we get ->
SELECT TA_NORMALIZED as TOKEN, COUNT(*) as COUNT 
FROM "LIVE2"."$TA_MYINDEX_VOC_WITH_CD" 
where TA_TYPE = 'LIVE 2 COUNTRY' 
GROUP BY TA_NORMALIZED
ORDER BY COUNT(*) DESC;

-- let's look an example with Iraq. These are the tweets based on LIVE 2 dictionary
--   where the country is Iraq
select "tweetId", "tweetContent" 
FROM  "LIVE2"."Tweets"
where "tweetId" in
(
SELECT "tweetId"
FROM "LIVE2"."$TA_MYINDEX_VOC_WITH_CD" 
where TA_TYPE = 'LIVE 2 COUNTRY'
and TA_NORMALIZED = 'Iraq'
)
order by 1;

-- These are the tweets based on original dictionary where the country is Iraq.
select "tweetId", "tweetContent" 
FROM  "LIVE2"."Tweets"
where "tweetId" in
(
SELECT "tweetId"
FROM "LIVE2"."$TA_MYINDEX_VOC_WITH_CD"
where TA_TYPE = 'COUNTRY'
and CONTAINS (TA_TOKEN,'Iraq')
)
order by 1;

-- This is the intersection of the 2 datasets. You can see the original dictionary 
--  missed non-Iraq and Iraq/Afghanistan. An option to fix this is Token Seperators.
select "tweetId", "tweetContent" 
FROM  "LIVE2"."Tweets"
where "tweetId" in
(
SELECT "tweetId"
FROM "LIVE2"."$TA_MYINDEX_VOC_WITH_CD" 
where TA_TYPE = 'LIVE 2 COUNTRY'
and TA_NORMALIZED = 'Iraq')
minus
select "tweetId", "tweetContent" 
FROM  "LIVE2"."Tweets"
where "tweetId" in
(
SELECT "tweetId"
FROM "LIVE2"."$TA_MYINDEX_VOC_WITH_CD"
where TA_TYPE = 'COUNTRY'
and CONTAINS (TA_TOKEN,'Iraq'))
;

-- .. but rather than that, let us see a bigger problem "US" (country) 
--  and "us" (pronoun)
select "tweetContent"
from "LIVE2"."Tweets"
where "tweetId" in
(
SELECT "tweetId"
FROM "LIVE2"."$TA_MYINDEX_VOC_WITH_CD"
where CONTAINS (TA_TOKEN,'us')
)
;

-- however, using the other configuration, we can identify pronouns ;
SELECT *
FROM "LIVE2"."$TA_MYINDEX_LING"  
where CONTAINS (TA_TOKEN,'us')
and TA_TYPE = 'pronoun'
order by 1;

-- so, what we need to do is get a list of tweets which contain US, but then minus
--  those which are pronouns
(SELECT "tweetId", "TA_SENTENCE", "TA_OFFSET"
FROM "LIVE2"."$TA_MYINDEX_VOC_WITH_CD" 
where TA_TYPE = 'LIVE 2 COUNTRY'
order by 1
)
minus
(
SELECT "tweetId", "TA_SENTENCE", "TA_OFFSET"
FROM "LIVE2"."$TA_MYINDEX_LING"  
where TA_TYPE = 'pronoun'
order by 1
);

-- once this is done, we can get a more accurate result, as below ;
SELECT TA_NORMALIZED as TOKEN, COUNT(*) as COUNT 
FROM "LIVE2"."$TA_MYINDEX_VOC_WITH_CD" 
where TA_TYPE = 'LIVE 2 COUNTRY' 
and "tweetId" || '-'  || "TA_SENTENCE" || '-' || "TA_OFFSET" in
(
(
SELECT "tweetId" || '-'  || "TA_SENTENCE" || '-' || "TA_OFFSET"
FROM "LIVE2"."$TA_MYINDEX_VOC_WITH_CD" 
where TA_TYPE = 'LIVE 2 COUNTRY'
order by 1
)
minus
(
SELECT "tweetId" || '-'  || "TA_SENTENCE" || '-' || "TA_OFFSET"
FROM "LIVE2"."$TA_MYINDEX_LING"  
where TA_TYPE = 'pronoun'
order by 1
)
)
GROUP BY TA_NORMALIZED
ORDER BY COUNT(*) DESC;