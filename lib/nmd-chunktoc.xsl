<?xml version='1.0'?>

<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:d="http://docbook.org/ns/docbook"
    xmlns="http://www.w3.org/1999/xhtml"
    version="1.0">

  <xsl:import href="@docbook_xsl_ns@/xml/xsl/docbook/xhtml/chunktoc.xsl"/>

  <xsl:template name="apply-highlighting">
    <xsl:if test="@language != ''">
      <xsl:attribute name="class">
        <xsl:value-of select="local-name()"/><xsl:text> </xsl:text><xsl:value-of select="@language"/>
      </xsl:attribute>
    </xsl:if>
    <xsl:apply-templates/>
  </xsl:template>

</xsl:stylesheet>
