<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:uri="http://xsltsl.org/uri"
                xmlns:str="http://xsltsl.org/string"
                xmlns:rdfa="https://www.w3.org/ns/rdfa#"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="html uri str rdfa">

<xsl:import href="rdfa2.xsl"/>

<xsl:output method="xml" media-type="text/html" indent="yes"/>

<xsl:template match="html:span[@class='merge-sort-tokens']">
  <span>W T F <xsl:value-of select="'1.1' &lt;= '2'"/></span>
  <xsl:text> </xsl:text>
  <xsl:call-template name="str:sort-tokens">
    <xsl:with-param name="string" select="."/>
    <!--<xsl:with-param name="descending" select="true()"/>-->
    <xsl:with-param name="unique" select="true()"/>
  </xsl:call-template>
</xsl:template>

<xsl:template match="html:*">
<xsl:param name="global-base" select="/html:html/html:head/html:base/@href"/>
<xsl:variable name="local-base" select="/html:html/html:head/html:base/@href"/>
<xsl:element name="{name()}"> <!-- namespace="{namespace-uri()}">-->
  <xsl:for-each select="@*">
    <xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
  </xsl:for-each>
  <xsl:apply-templates>
    <xsl:with-param name="global-base" select="$global-base"/>
  </xsl:apply-templates>
</xsl:element>
</xsl:template>

<xsl:template match="*">
<xsl:param name="global-base" select="ancestor-or-self::*[@xml:base][1]/@xml:base"/>
<xsl:param name="local-base" select="ancestor-or-self::*[@xml:base][1]/@xml:base"/>
<xsl:element name="{name()}"> <!-- namespace="{namespace-uri()}">-->
  <xsl:for-each select="@*">
    <xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
  </xsl:for-each>
  <xsl:apply-templates>
    <xsl:with-param name="global-base" select="$global-base"/>
    <xsl:with-param name="local-base" select="$local-base"/>
  </xsl:apply-templates>
</xsl:element>
</xsl:template>

</xsl:stylesheet>