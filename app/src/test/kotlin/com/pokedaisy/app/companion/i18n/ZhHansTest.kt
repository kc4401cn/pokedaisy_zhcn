package com.pokedaisy.app.companion.i18n

import com.pokedaisy.app.companion.data.DexTextZh
import com.pokedaisy.app.companion.data.readsAsText
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.Locale

/** The Chinese tables, and the junk-text rule that decides when the app falls back to them. */
class ZhHansTest {
    /** The tables answer on a Chinese screen only - see [nothingOnOtherLanguages]. */
    @Before fun chinese() = L10n.apply("ZH", null)
    @After fun reset() = L10n.apply("EN", null)

    /** A translated ROM's own character set decodes as Latin-1 leftovers and U+FFFD, never as text. */
    @Test fun junkIsNotText() {
        assertFalse("IoÉ↑Ès".readsAsText())
        assertFalse("ÎoÉ↑Ès".readsAsText())
        assertFalse("?????".readsAsText())
        assertFalse("\uFFFD\uFFFD".readsAsText())
        assertFalse("".readsAsText())
        assertFalse("   ".readsAsText())
    }

    /** A real name reads as text, whatever its script. */
    @Test fun realNamesAreText() {
        assertTrue("Marill".readsAsText())
        assertTrue("Sparky".readsAsText())
        assertTrue("小丸".readsAsText())
    }

    /** One odd character in a long name is not enough to call it junk. */
    @Test fun mostlyTextIsText() {
        assertTrue("abcdefÉ".readsAsText())
    }

    /**
     * The rule leans towards calling junk junk: a translated ROM's one-character nickname
     * decodes to a single high character, and that has to fall back to the species name.
     * A short accented name ("é") is therefore read as junk too - rare enough to accept.
     */
    @Test fun aSingleHighCharacterIsJunk() {
        assertFalse("é".readsAsText())
        assertFalse("É".readsAsText())
    }

    /** The official names, by id. */
    @Test fun theOfficialNames() {
        assertEquals("妙蛙种子", GameNamesZh.speciesName(1))
        assertEquals("皮卡丘", GameNamesZh.speciesName(25))
        assertEquals("大师球", GameNamesZh.itemName(1))
        assertEquals("拍击", GameNamesZh.moveName(1))
        assertEquals("恶臭", GameNamesZh.ability(1))
        assertEquals("孢子", GameNamesZh.ability(27))
        assertNull(GameNamesZh.speciesName(0))
        assertNull(GameNamesZh.ability(9999))
    }

    /** A place's own name, or the official wording for a numbered road. */
    @Test fun placesAndRoads() {
        assertEquals("真新镇", GameNamesZh.place("PALLET TOWN"))
        assertEquals("10号道路", GameNamesZh.place("ROUTE 10"))
        // Not in the table: the numbered-road rule has it.
        assertEquals("102号道路", GameNamesZh.place("ROUTE 102"))
        assertEquals("12-15号道路", GameNamesZh.place("ROUTES 12-15"))
        assertNull(GameNamesZh.place("NOWHERE"))
    }

    /** The dex's genus and flavour text, by national number. */
    @Test fun theDexText() {
        assertEquals("种子宝可梦", DexTextZh.entry(1)?.first)
        assertNotNull(DexTextZh.entry(1)?.second)
        assertNull(DexTextZh.entry(0))
        assertNull(DexTextZh.entry(387))
    }

    /** Every species the tables cover has a genus and a flavour text, and no entry is blank. */
    @Test fun theDexTablesMatch() {
        for (national in 1..386) {
            val entry = DexTextZh.entry(national)
            assertNotNull("no dex entry for $national", entry)
            assertTrue("blank genus for $national", entry!!.first.isNotBlank())
            assertTrue("blank flavour for $national", entry.second.isNotBlank())
        }
    }

    /**
     * The official Chinese names use half-width digits and letters ("10号道路", "PP提升剂").
     * PokéAPI's zh-hans has them full-width; the official ROMs don't, so neither do we.
     */
    @Test fun noFullWidthDigitsOrLetters() {
        val fullWidth = { c: Char -> c.code in 0xFF10..0xFF19 || c.code in 0xFF21..0xFF3A || c.code in 0xFF41..0xFF5A }
        fun check(what: String, names: Collection<String>) {
            names.forEach { name ->
                assertFalse("$what: full-width in '$name'", name.any(fullWidth))
                assertFalse("$what: blank", name.isBlank())
            }
        }
        check("species", GameNamesZh.species.values)
        check("items", GameNamesZh.items.values)
        check("moves", GameNamesZh.moves.values)
        check("types", GameNamesZh.types.values)
        check("places", GameNamesZh.places.values)
        check("itemDescs", GameNamesZh.itemDescs.values)
        check("abilities", GameNamesZh.abilities.values)
        // The GUIDE's own pages carry the same names.
        check("guide", guideTranslations.values.mapNotNull { it.zh })
    }

    /** On any other language the tables answer nothing: the ROM's own names are used there. */
    @Test fun nothingOnOtherLanguages() {
        L10n.apply("EN", null)
        assertNull(GameNamesZh.speciesName(1))
        assertNull(GameNamesZh.itemName(1))
        assertNull(GameNamesZh.moveName(1))
        assertNull(GameNamesZh.typeName(0))
        assertNull(GameNamesZh.ability(1))
        assertNull(GameNamesZh.itemDescription(1))
        assertNull(GameNamesZh.place("PALLET TOWN"))
        assertNull("the dex too", DexTextZh.entry(1))
    }

    /** Chinese is a language of its own: the device's picks it, and a ROM never does. */
    @Test fun chineseIsALanguage() {
        assertEquals(AppLanguage.ZH, AppLanguage.ofLocale(Locale.SIMPLIFIED_CHINESE))
        assertEquals(AppLanguage.ZH, AppLanguage.ofCode("ZH"))
        assertNull(AppLanguage.ofCode("XX"))
        assertEquals(AppLanguage.ZH.nativeName, "中文")
    }
}
