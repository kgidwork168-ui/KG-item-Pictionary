(function () {
  "use strict";

  const config = window.KG_CONFIG || {};
  const configured = config.SUPABASE_URL && !config.SUPABASE_URL.includes("YOUR_") && config.SUPABASE_ANON_KEY && !config.SUPABASE_ANON_KEY.includes("YOUR_");
  const db = configured ? window.supabase.createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY) : null;

  const state = { categories: [], products: [], selectedCategory: "all", query: "", adminToken: "", adminProfile: null, isAdmin: false, isMainAdmin: false, adminUsers: [], demo: !configured };
  const el = (id) => document.getElementById(id);
  const escapeHtml = (value = "") => String(value).replace(/[&<>'"]/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[char]);
  const normalise = (value) => String(value || "").trim().toLowerCase();
  const uid = () => (crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random()}`);

  const demoCategories = [
    { id: "demo-board", name_en: "Board", name_zh: "板材", sort_order: 1 },
    { id: "demo-metal", name_en: "Metal", name_zh: "金属", sort_order: 2 },
    { id: "demo-screw", name_en: "Screw", name_zh: "螺丝", sort_order: 3 }
  ];
  const demoProducts = [
    {
      id: "demo-1", category_id: "demo-board", name_en: "Calcium Silicate Board", name_zh: "硅酸钙板", image_url: "", sort_order: 1,
      variants: [
        { id: "v1", manual_number: "CS001", size: "9mm × 1220 × 2440", colour_en: "White", colour_zh: "白色", sort_order: 1 },
        { id: "v2", manual_number: "CS002", size: "12mm × 1220 × 2440", colour_en: "White", colour_zh: "白色", sort_order: 2 },
        { id: "v3", manual_number: "CS003", size: "12mm × 1220 × 2440", colour_en: "Green", colour_zh: "绿色", sort_order: 3 }
      ]
    },
    {
      id: "demo-2", category_id: "demo-metal", name_en: "Galvanised Ceiling Channel", name_zh: "镀锌天花龙骨", image_url: "", sort_order: 2,
      variants: [
        { id: "v4", manual_number: "MT101", size: "38mm × 12mm", colour_en: "", colour_zh: "", sort_order: 1 },
        { id: "v5", manual_number: "MT102", size: "50mm × 19mm", colour_en: "", colour_zh: "", sort_order: 2 }
      ]
    },
    {
      id: "demo-3", category_id: "demo-screw", name_en: "Drywall Screw", name_zh: "石膏板螺丝", image_url: "", sort_order: 3,
      variants: [{ id: "v6", manual_number: "SC025", size: "25mm", colour_en: "Black", colour_zh: "黑色", sort_order: 1 }]
    }
  ];

  async function init() {
    bindEvents();
    if (state.demo) {
      state.categories = demoCategories;
      state.products = demoProducts;
      showNotice("Demo data is shown. Add your Supabase details in config.js to load your real materials.");
      renderAll();
      return;
    }
    state.adminToken = sessionStorage.getItem("kg_admin_session") || "";
    await checkAdmin();
    await loadData();
  }

  async function checkAdmin() {
    state.isAdmin = false;
    state.isMainAdmin = false;
    state.adminProfile = null;
    if (!state.adminToken) return;
    try {
      const result = await callAdminFunction({ action: "me" });
      state.adminProfile = result.profile || null;
      state.isAdmin = Boolean(state.adminProfile);
      state.isMainAdmin = Boolean(state.adminProfile?.is_main_admin);
    } catch (_) {
      sessionStorage.removeItem("kg_admin_session");
      state.adminToken = "";
    }
  }

  async function loadData() {
    setLoading(true);
    const [categoryResult, productResult, variantResult] = await Promise.all([
      db.from("categories").select("id,name_en,name_zh,sort_order").eq("is_active", true).order("sort_order").order("name_en"),
      db.from("products").select("id,category_id,name_en,name_zh,image_url,sort_order").eq("is_active", true).order("sort_order").order("name_en"),
      // Deliberately requests no price fields.
      db.from("product_variants").select("id,product_id,manual_number,size,colour_en,colour_zh,sort_order").eq("is_active", true).order("sort_order").order("manual_number")
    ]);
    const firstError = categoryResult.error || productResult.error || variantResult.error;
    if (firstError) {
      showNotice(`Unable to load materials: ${firstError.message}`);
      setLoading(false);
      return;
    }
    state.categories = categoryResult.data || [];
    state.products = (productResult.data || []).map((product) => ({
      ...product,
      variants: (variantResult.data || []).filter((variant) => variant.product_id === product.id)
    }));
    setLoading(false);
    renderAll();
  }

  function setLoading(loading) {
    if (loading) el("materialsGrid").innerHTML = '<div class="empty-state"><h2>Loading…</h2><p>正在加载材料</p></div>';
  }

  function categoryFor(product) { return state.categories.find((category) => category.id === product.category_id) || {}; }

  function filteredProducts() {
    const q = normalise(state.query);
    return state.products.filter((product) => {
      if (state.selectedCategory !== "all" && product.category_id !== state.selectedCategory) return false;
      if (!q) return true;
      const category = categoryFor(product);
      const productText = [product.name_en, product.name_zh, category.name_en, category.name_zh].map(normalise).join(" ");
      const variantMatch = (product.variants || []).some((variant) => [variant.manual_number, variant.size, variant.colour_en, variant.colour_zh].map(normalise).join(" ").includes(q));
      return productText.includes(q) || variantMatch;
    });
  }

  function visibleVariants(product) {
    const q = normalise(state.query);
    if (!q) return product.variants || [];
    const category = categoryFor(product);
    const headerText = [product.name_en, product.name_zh, category.name_en, category.name_zh].map(normalise).join(" ");
    if (headerText.includes(q)) return product.variants || [];
    return (product.variants || []).filter((variant) => [variant.manual_number, variant.size, variant.colour_en, variant.colour_zh].map(normalise).join(" ").includes(q));
  }

  function renderAll() {
    renderCategories();
    renderMaterials();
    renderAdminState();
  }

  function renderCategories() {
    const navRows = [{ id: "all", name_en: "All Materials", name_zh: "全部材料" }, ...state.categories];
    el("categoryNav").innerHTML = navRows.map((category) => `
      <button class="category-button ${state.selectedCategory === category.id ? "active" : ""}" data-category="${escapeHtml(category.id)}" type="button">
        <span class="category-dot"></span>
        <span class="category-label"><strong>${escapeHtml(category.name_en)}</strong><small>${escapeHtml(category.name_zh || "")}</small></span>
        <span class="category-count">${category.id === "all" ? state.products.length : state.products.filter((product) => product.category_id === category.id).length}</span>
      </button>`).join("");
    el("mobileCategorySelect").innerHTML = navRows.map((category) => `<option value="${escapeHtml(category.id)}" ${state.selectedCategory === category.id ? "selected" : ""}>${escapeHtml(category.name_en)} / ${escapeHtml(category.name_zh || "")}</option>`).join("");
    const chosen = navRows.find((category) => category.id === state.selectedCategory) || navRows[0];
    el("catalogueHeading").textContent = `${chosen.name_en} / ${chosen.name_zh || ""}`;
  }

  function renderMaterials() {
    const products = filteredProducts();
    el("resultCount").textContent = `${products.length} material${products.length === 1 ? "" : "s"} found / 找到 ${products.length} 项材料`;
    el("materialTotal").textContent = products.length;
    el("variantTotal").textContent = products.reduce((total, product) => total + visibleVariants(product).length, 0);
    if (!products.length) {
      el("materialsGrid").innerHTML = '<div class="empty-state"><h2>No material found / 找不到材料</h2><p>Try another name, manual number, size or colour.</p></div>';
      return;
    }
    el("materialsGrid").innerHTML = products.map((product) => {
      const category = categoryFor(product);
      const variants = visibleVariants(product);
      const image = product.image_url
        ? `<img class="material-image" src="${escapeHtml(product.image_url)}" alt="${escapeHtml(product.name_en)}" loading="lazy" onerror="this.style.display='none';this.nextElementSibling.style.display='grid'" /><div class="image-placeholder" style="display:none"><div><span>▧</span>Picture unavailable<br />图片无法显示</div></div><span class="image-reference">REFERENCE / 参考</span>`
        : '<div class="image-placeholder"><div><span>▧</span>No picture yet<br />尚未上传图片</div></div>';
      const rows = variants.length ? `
        <div class="specification-label">AVAILABLE SPECIFICATIONS / 可选规格</div>
        <table class="variant-table">
          <thead><tr><th>Manual No.<br />材料编号</th><th>Size<br />尺寸</th><th>Colour<br />颜色</th></tr></thead>
          <tbody>${variants.map((variant) => `<tr><td class="manual-number">${escapeHtml(variant.manual_number || "—")}</td><td>${escapeHtml(variant.size || "—")}</td><td>${escapeHtml([variant.colour_en, variant.colour_zh].filter(Boolean).join(" / ") || "—")}</td></tr>`).join("")}</tbody>
        </table>` : '<p class="empty-variants">No variant added / 尚未添加规格</p>';
      return `<article class="material-card">
        <div class="material-image-wrap">${image}</div>
        <div class="material-body">
          <div class="material-heading">
            <div class="material-heading-text">
              <span class="category-pill">${escapeHtml(category.name_en || "Uncategorised")} / ${escapeHtml(category.name_zh || "未分类")}</span>
              <h2 class="material-name">${escapeHtml(product.name_en)}</h2>
              <p class="material-name-zh">${escapeHtml(product.name_zh || "")}</p>
            </div>
            ${state.isAdmin ? `<div class="card-actions"><button class="icon-button" data-edit-item="${escapeHtml(product.id)}" title="Edit item" type="button">✎</button><button class="danger-icon" data-delete-item="${escapeHtml(product.id)}" title="Delete item" type="button">⌫</button></div>` : ""}
          </div>
          ${rows}
        </div>
      </article>`;
    }).join("");
  }

  function renderAdminState() {
    el("adminActions").classList.toggle("hidden", !state.isAdmin);
    el("manageAdminsButton").classList.toggle("hidden", !state.isMainAdmin);
    const signedInName = state.adminProfile?.display_name || state.adminProfile?.username || "Admin";
    el("adminButtonText").innerHTML = state.isAdmin ? `${escapeHtml(signedInName)}<br><small>Logout / 退出</small>` : "Admin<br><small>管理员登录</small>";
  }

  function bindEvents() {
    el("categoryNav").addEventListener("click", (event) => {
      const button = event.target.closest("[data-category]");
      if (!button) return;
      chooseCategory(button.dataset.category);
      closeSidebar();
    });
    el("mobileCategorySelect").addEventListener("change", (event) => chooseCategory(event.target.value));
    el("searchInput").addEventListener("input", (event) => {
      state.query = event.target.value;
      el("clearSearchButton").classList.toggle("hidden", !state.query);
      renderMaterials();
    });
    el("clearSearchButton").addEventListener("click", () => {
      state.query = ""; el("searchInput").value = ""; el("clearSearchButton").classList.add("hidden"); renderMaterials(); el("searchInput").focus();
    });
    el("menuButton").addEventListener("click", openSidebar);
    el("sidebarBackdrop").addEventListener("click", closeSidebar);
    el("printButton").addEventListener("click", () => window.print());
    el("adminButton").addEventListener("click", handleAdminButton);
    el("loginForm").addEventListener("submit", login);
    el("addItemButton").addEventListener("click", () => openItemForm());
    el("manageAdminsButton").addEventListener("click", openAdminUsers);
    el("manageCategoriesButton").addEventListener("click", openCategoryForm);
    el("addVariantButton").addEventListener("click", () => addVariantRow());
    el("variantEditor").addEventListener("click", (event) => { if (event.target.closest("[data-remove-variant]")) event.target.closest(".variant-edit-row").remove(); });
    el("materialsGrid").addEventListener("click", handleCardAction);
    el("itemForm").addEventListener("submit", saveItem);
    el("categoryForm").addEventListener("submit", saveCategories);
    el("newCategoryButton").addEventListener("click", () => addCategoryRow());
    el("categoryEditor").addEventListener("click", (event) => { if (event.target.closest("[data-remove-category]")) event.target.closest(".category-edit-row").remove(); });
    el("newAdminUserButton").addEventListener("click", resetAdminUserForm);
    el("cancelAdminEditButton").addEventListener("click", resetAdminUserForm);
    el("adminUserForm").addEventListener("submit", saveAdminUser);
    el("adminUserList").addEventListener("click", (event) => {
      const edit = event.target.closest("[data-edit-admin]");
      if (edit) editAdminUser(edit.dataset.editAdmin);
    });
    document.querySelectorAll("[data-close-dialog]").forEach((button) => button.addEventListener("click", () => button.closest("dialog").close()));
  }

  function chooseCategory(id) { state.selectedCategory = id; renderCategories(); renderMaterials(); }
  function openSidebar() { el("sidebar").classList.add("open"); el("sidebarBackdrop").classList.add("open"); }
  function closeSidebar() { el("sidebar").classList.remove("open"); el("sidebarBackdrop").classList.remove("open"); }
  function showNotice(message) { el("notice").textContent = message; el("notice").classList.remove("hidden"); }
  function hideNotice() { el("notice").classList.add("hidden"); }

  async function handleAdminButton() {
    if (state.demo) { showNotice("Connect Supabase in config.js before using Admin Login."); return; }
    if (state.adminToken) {
      try { await callAdminFunction({ action: "logout" }); } catch (_) { /* local logout still completes */ }
      sessionStorage.removeItem("kg_admin_session");
      state.adminToken = ""; state.adminProfile = null; state.isAdmin = false; state.isMainAdmin = false; renderAll();
    } else {
      el("loginError").classList.add("hidden"); el("loginDialog").showModal();
    }
  }

  async function login(event) {
    event.preventDefault();
    const errorBox = el("loginError"); errorBox.classList.add("hidden");
    const username = normalise(el("loginUsername").value);
    try {
      const result = await callAdminFunction({ action: "login", username, password: el("loginPassword").value }, false);
      state.adminToken = result.session_token;
      state.adminProfile = result.profile;
      state.isAdmin = true;
      state.isMainAdmin = Boolean(result.profile?.is_main_admin);
      sessionStorage.setItem("kg_admin_session", state.adminToken);
      el("loginDialog").close(); el("loginForm").reset(); renderAll();
    } catch (error) {
      errorBox.textContent = error.message || "Login failed. / 登录失败";
      errorBox.classList.remove("hidden");
    }
  }

  function requireAdmin() { if (!state.isAdmin) { showNotice("Admin login required. / 请先登录管理员账号"); return false; } return true; }

  function requireMainAdmin() {
    if (!state.isMainAdmin) { showNotice("Only the Main Admin can manage admin users. / 只有主管理员可以管理账号"); return false; }
    return true;
  }

  async function callAdminFunction(body, useSession = true) {
    const headers = useSession && state.adminToken ? { "x-admin-session": state.adminToken } : {};
    const { data, error } = await db.functions.invoke("pictionary-admin", { body, headers });
    if (error) {
      let message = error.message || "Admin user service is unavailable.";
      if (error.context && typeof error.context.json === "function") {
        try { message = (await error.context.json())?.error || message; } catch (_) { /* keep the safe fallback */ }
      }
      throw new Error(message);
    }
    if (!data?.ok) throw new Error(data?.error || "Unable to manage admin user.");
    return data;
  }

  async function openAdminUsers() {
    if (!requireMainAdmin()) return;
    resetAdminUserForm();
    el("adminUserList").innerHTML = '<div class="admin-loading">Loading admin users…</div>';
    el("adminUsersDialog").showModal();
    await loadAdminUsers();
  }

  async function loadAdminUsers() {
    try {
      const result = await callAdminFunction({ action: "list" });
      state.adminUsers = result.admins || [];
      renderAdminUsers();
    } catch (error) {
      el("adminUserList").innerHTML = `<p class="form-error">${escapeHtml(error.message)}</p>`;
    }
  }

  function renderAdminUsers() {
    if (!state.adminUsers.length) {
      el("adminUserList").innerHTML = '<div class="admin-loading">No administrator found.</div>';
      return;
    }
    el("adminUserList").innerHTML = state.adminUsers.map((admin) => `
      <article class="admin-user-row">
        <div class="admin-avatar">${escapeHtml((admin.display_name || admin.username || "A").slice(0, 1).toUpperCase())}</div>
        <div class="admin-user-details">
          <strong>${escapeHtml(admin.display_name || admin.username)}</strong>
          <span>@${escapeHtml(admin.username || "admin")}</span>
        </div>
        <span class="role-badge ${admin.is_main_admin ? "main" : admin.is_active ? "active" : "inactive"}">${admin.is_main_admin ? "Main Admin" : admin.is_active ? "Admin" : "Inactive"}</span>
        ${admin.is_main_admin ? "" : `<button class="icon-button" data-edit-admin="${escapeHtml(admin.user_id)}" type="button" title="Edit admin">✎</button>`}
      </article>`).join("");
  }

  function resetAdminUserForm() {
    el("adminUserForm").reset();
    el("adminUserId").value = "";
    el("adminIsActive").checked = true;
    el("adminPassword").required = true;
    el("adminUserFormTitle").textContent = "Add Admin / 新增管理员";
    el("adminPasswordLabel").textContent = "Temporary Password / 临时密码";
    el("adminPasswordHelp").textContent = "Minimum 8 characters. The new admin can log in immediately.";
    el("cancelAdminEditButton").classList.add("hidden");
    el("adminUserFormError").classList.add("hidden");
  }

  function editAdminUser(userId) {
    const admin = state.adminUsers.find((item) => item.user_id === userId);
    if (!admin || admin.is_main_admin) return;
    el("adminUserId").value = admin.user_id;
    el("adminUsername").value = admin.username || "";
    el("adminDisplayName").value = admin.display_name || "";
    el("adminPassword").value = "";
    el("adminPassword").required = false;
    el("adminIsActive").checked = admin.is_active;
    el("adminUserFormTitle").textContent = "Edit Admin / 编辑管理员";
    el("adminPasswordLabel").textContent = "New Password / 新密码（选填）";
    el("adminPasswordHelp").textContent = "Leave password blank to keep the current password.";
    el("cancelAdminEditButton").classList.remove("hidden");
    el("adminUserFormError").classList.add("hidden");
    el("adminUsername").focus();
  }

  async function saveAdminUser(event) {
    event.preventDefault();
    if (!requireMainAdmin()) return;
    const errorBox = el("adminUserFormError");
    errorBox.classList.add("hidden");
    const userId = el("adminUserId").value;
    const password = el("adminPassword").value;
    const body = {
      action: userId ? "update" : "create",
      user_id: userId || undefined,
      username: normalise(el("adminUsername").value),
      display_name: el("adminDisplayName").value.trim(),
      password: password || undefined,
      is_active: el("adminIsActive").checked
    };
    try {
      await callAdminFunction(body);
      resetAdminUserForm();
      await loadAdminUsers();
    } catch (error) {
      errorBox.textContent = error.message || String(error);
      errorBox.classList.remove("hidden");
    }
  }

  function handleCardAction(event) {
    const edit = event.target.closest("[data-edit-item]");
    const remove = event.target.closest("[data-delete-item]");
    if (edit) openItemForm(state.products.find((product) => product.id === edit.dataset.editItem));
    if (remove) deleteItem(remove.dataset.deleteItem);
  }

  function openItemForm(product = null) {
    if (!requireAdmin()) return;
    el("itemForm").reset(); el("variantEditor").innerHTML = ""; el("itemFormError").classList.add("hidden");
    el("itemCategory").innerHTML = state.categories.map((category) => `<option value="${escapeHtml(category.id)}">${escapeHtml(category.name_en)} / ${escapeHtml(category.name_zh || "")}</option>`).join("");
    el("itemDialogTitle").textContent = product ? "Edit Item / 编辑材料" : "Add Item / 新增材料";
    el("itemId").value = product?.id || "";
    el("itemCategory").value = product?.category_id || state.selectedCategory !== "all" && state.categories.some((c) => c.id === state.selectedCategory) ? (product?.category_id || state.selectedCategory) : (state.categories[0]?.id || "");
    el("itemSortOrder").value = product?.sort_order ?? 0;
    el("itemNameEn").value = product?.name_en || "";
    el("itemNameZh").value = product?.name_zh || "";
    el("itemImageUrl").value = product?.image_url || "";
    (product?.variants?.length ? product.variants : [{}]).forEach(addVariantRow);
    el("itemDialog").showModal();
  }

  function addVariantRow(variant = {}) {
    const row = el("variantRowTemplate").content.firstElementChild.cloneNode(true);
    row.dataset.variantId = variant.id || "";
    row.querySelectorAll("[data-field]").forEach((input) => { input.value = variant[input.dataset.field] ?? (input.dataset.field === "sort_order" ? 0 : ""); });
    el("variantEditor").appendChild(row);
  }

  async function uploadImage(productId) {
    const file = el("itemImage").files[0];
    if (!file) return el("itemImageUrl").value.trim();
    const extension = (file.name.split(".").pop() || "jpg").toLowerCase();
    const path = `${productId}/${Date.now()}-${uid()}.${extension}`;
    const signed = await callAdminFunction({ action: "create-upload-url", path });
    const { error } = await db.storage.from(config.IMAGE_BUCKET || "product-images").uploadToSignedUrl(signed.path, signed.token, file, { cacheControl: "3600" });
    if (error) throw error;
    return db.storage.from(config.IMAGE_BUCKET || "product-images").getPublicUrl(signed.path).data.publicUrl;
  }

  async function saveItem(event) {
    event.preventDefault(); if (!requireAdmin()) return;
    const errorBox = el("itemFormError"); errorBox.classList.add("hidden");
    const rows = [...el("variantEditor").querySelectorAll(".variant-edit-row")];
    const variants = rows.map((row, index) => ({
      manual_number: row.querySelector('[data-field="manual_number"]').value.trim(),
      size: row.querySelector('[data-field="size"]').value.trim() || null,
      colour_en: row.querySelector('[data-field="colour_en"]').value.trim() || null,
      colour_zh: row.querySelector('[data-field="colour_zh"]').value.trim() || null,
      sort_order: Number(row.querySelector('[data-field="sort_order"]').value || index), is_active: true
    }));
    const manualNumbers = variants.map((variant) => normalise(variant.manual_number));
    if (manualNumbers.some((manual, index) => manualNumbers.indexOf(manual) !== index)) { errorBox.textContent = "Manual No. cannot be repeated. / 材料编号不可重复"; errorBox.classList.remove("hidden"); return; }
    try {
      let productId = el("itemId").value || uid();
      const imageUrl = await uploadImage(productId);
      const productPayload = {
        id: productId, category_id: el("itemCategory").value, name_en: el("itemNameEn").value.trim(), name_zh: el("itemNameZh").value.trim() || null,
        image_url: imageUrl || null, sort_order: Number(el("itemSortOrder").value || 0), is_active: true
      };
      await callAdminFunction({ action: "save-item", product: productPayload, variants });
      el("itemDialog").close(); hideNotice(); await loadData();
    } catch (error) { errorBox.textContent = error.message || String(error); errorBox.classList.remove("hidden"); }
  }

  async function deleteItem(productId) {
    if (!requireAdmin() || !confirm("Delete this item and all its variants? / 删除此材料和全部规格？")) return;
    try { await callAdminFunction({ action: "delete-item", product_id: productId }); await loadData(); }
    catch (error) { showNotice(error.message || String(error)); }
  }

  function openCategoryForm() {
    if (!requireAdmin()) return;
    el("categoryEditor").innerHTML = ""; el("categoryFormError").classList.add("hidden"); state.categories.forEach(addCategoryRow); el("categoryDialog").showModal();
  }

  function addCategoryRow(category = {}) {
    const row = el("categoryRowTemplate").content.firstElementChild.cloneNode(true);
    row.querySelector("[data-category-id]").value = category.id || "";
    row.querySelectorAll("[data-category-field]").forEach((input) => { input.value = category[input.dataset.categoryField] ?? (input.dataset.categoryField === "sort_order" ? 0 : ""); });
    el("categoryEditor").appendChild(row);
  }

  async function saveCategories(event) {
    event.preventDefault(); if (!requireAdmin()) return;
    const errorBox = el("categoryFormError"); errorBox.classList.add("hidden");
    const rows = [...el("categoryEditor").querySelectorAll(".category-edit-row")];
    const payload = rows.map((row) => ({
      id: row.querySelector("[data-category-id]").value || uid(),
      name_en: row.querySelector('[data-category-field="name_en"]').value.trim(),
      name_zh: row.querySelector('[data-category-field="name_zh"]').value.trim() || null,
      sort_order: Number(row.querySelector('[data-category-field="sort_order"]').value || 0), is_active: true
    }));
    const removedIds = state.categories.filter((category) => !payload.some((item) => item.id === category.id)).map((category) => category.id);
    try {
      await callAdminFunction({ action: "save-categories", categories: payload, removed_ids: removedIds });
      el("categoryDialog").close(); await loadData();
    } catch (error) { errorBox.textContent = error.message || String(error); errorBox.classList.remove("hidden"); }
  }

  init();
})();
