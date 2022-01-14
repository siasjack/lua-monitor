
include $(TOPDIR)/rules.mk

PKG_NAME:=lua-monitor
PKG_RELEASE:=1
PKG_LICENSE:=
PKG_LICENSE_FILES:=
#PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)
include $(INCLUDE_DIR)/package.mk
RSTRIP:=:
STRIP:=:


define Package/lua-monitor
  SUBMENU:=Lua
  SECTION:=lang
  CATEGORY:=Languages
  TITLE:=Lua-monitor
  DEPENDS:= +luasocket +luafilesystem +lua-cjson
endef

define Package/lua-monitor/description
 This package is for lua-monitor
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Package/lua-monitor/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/monitor.lua $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/monitor-ctrl.lua $(1)/usr/bin
	$(INSTALL_BIN) ./file/monitor.init $(1)/etc/init.d/monitor
	$(CP) ./file/monitor.config $(1)/etc/config
endef

$(eval $(call BuildPackage,lua-monitor))
