---
name: mr-description
description: Used when a feature is finished and we want to create a description for the Gitlab/Github code review
allowed-tools:
  - Read
  - Write
  - Bash
---

# Merge Request Description Skill

formuliere eine MR description auf englisch. bitte halte dich so kurz und knapp wie möglich. beschreibe im ersten abschnitt warum das feature implementiert wurde. im zweiten abschnitt beschreibe wie das feature testbar ist, was der code reviewer lokal machen muss damit er alles reproduzieren kann.
falls es kleine notes noch gibt die sinn machen würden anzuhängen, hänge diese bitte als notes hinten an.
schreibe die MR description immer in eine markdown file im /tmp ordner und gib dem user einfach nur den pfad dort hin anstatt alles noch mal vorzulesen.
bitte baue immer am anfang der description einen platz für die url zum ticket ein.
