/// Preset transcribed from "딸깍야짤용 와카 업데이트7" (2026-05-25).
/// Wildcards resolve against the user's existing imported wildcard directory.
class NaiaUpdate7Preset {
  const NaiaUpdate7Preset._();

  static const leadingPrompt =
      'nsfw, 1girl, __대분류__, __사정여부__, __배경_의상__,';

  static const requiredWildcards = <String>[
    '대분류', '사정여부', '배경_의상', '체위/섹스', '체위/그룹섹스',
    '체위/파이즈리', '체위/펠라', '체위/핑거링', '체위/핸드잡',
    '체위/커닐링구스', '체위/자위', '체위/기타', '의상/의상',
  ];

  static const rules = r'''(masturbation):1girl+=solo,
(sex|paizuri|fellatio|fingering|handjob|cunnilingus|masturbation):nsfw+=uncensored,
(~masturbation&~!group sex&~!etc):1girl+=1boy,
(*group sex):1girl+=multiple boys,
(sex&~!group sex):sex+=__체위/섹스__,
(*group sex):group sex+=__체위/그룹섹스__,
(paizuri):paizuri+=__체위/파이즈리__,
(fellatio):fellatio+=__체위/펠라__,
(fingering):fingering+=__체위/핑거링__,
(handjob):handjob+=__체위/핸드잡__,
(cunnilingus):cunnilingus+=__체위/커닐링구스__,
(masturbation):masturbation+=__체위/자위__,
(*etc):ejaculation= ,
(*etc):-1::ejaculation= ,
(*etc):etc=__체위/기타__,
(*white background, simple background):simple background+=__의상/의상__,
(*bedroom):bedroom+=__의상/의상__,
(*ejaculation&sex):ejaculation+=cum in pussy^cum overflow^cumdrip,
(*ejaculation&fellatio):ejaculation+=cum in mouth^cum overflow,
(*ejaculation&paizuri):ejaculation+=cum overflow,
(*ejaculation&handjob):ejaculation+=cum overflow,
(*ejaculation&cunnilingus):ejaculation=female ejaculation^pussy juice^pussy juice puddle,
(*ejaculation&fingering):ejaculation=female ejaculation^pussy juice^pussy juice puddle,
(*ejaculation&masturbation):ejaculation=female ejaculation^pussy juice^pussy juice puddle,''';
}
