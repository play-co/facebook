<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:android="http://schemas.android.com/apk/res/android">

	<xsl:param name="facebookAppID" />
	<xsl:param name="facebookDisplayName" />

	<xsl:output indent="yes" />
	<xsl:template match="comment()" />

	<xsl:template match="meta-data[@android:name='FACEBOOK_APP_ID']">
		<meta-data android:name="FACEBOOK_APP_ID" android:value="\ {$facebookAppID}"/>
	</xsl:template>

	<xsl:template match="meta-data[@android:name='FACEBOOK_DISPLAY_NAME']">
		<meta-data android:name="FACEBOOK_DISPLAY_NAME" android:value="{$facebookDisplayName}"/>
	</xsl:template>

	<xsl:template match="meta-data[@android:name='com.facebook.sdk.ApplicationId']">
		<meta-data android:name="com.facebook.sdk.ApplicationId" android:value="\ {$facebookAppID}"/>
	</xsl:template>

	<xsl:template match="activity[@android:name='com.facebook.LoginActivity']">
		<activity android:name="com.facebook.LoginActivity"
			android:theme="@android:style/Theme.Translucent.NoTitleBar"
			android:label="{$facebookDisplayName}" />
	</xsl:template>

	<xsl:template match="@*|node()">
		<xsl:copy>
			<xsl:apply-templates select="@*|node()" />
		</xsl:copy>
	</xsl:template>
</xsl:stylesheet>
