import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropdown", "results", "pillsContainer", "field", "pill"]
  static values = {
    searchUrl: String,
    createUrl: String,
    destroyUrlTemplate: String,
    appliedTagIds: Array,
    csrf: String
  }

  connect() {
    this.debounceTimer = null
    this.currentResults = []
    this.highlightedIndex = -1
    this.boundOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener("click", this.boundOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutsideClick)
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
  }

  focusInput(event) {
    if (event.target.closest("[data-tag-input-target='pill']")) return
    this.inputTarget.focus()
  }

  focus() {
    const value = this.inputTarget.value.trim()
    if (value.length >= 1) {
      this.search(value)
    } else {
      this.openDropdown()
      this.renderResults([])
    }
  }

  type() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => {
      const value = this.inputTarget.value.trim()
      if (value.length < 1) {
        this.renderResults([])
        return
      }
      this.search(value)
    }, 150)
  }

  async search(query) {
    try {
      const url = `${this.searchUrlValue}?q=${encodeURIComponent(query)}`
      const res = await fetch(url, {
        headers: { "Accept": "application/json" },
        credentials: "same-origin"
      })
      if (!res.ok) throw new Error("Search failed")
      const results = await res.json()
      this.currentResults = results
      this.renderResults(results)
      this.openDropdown()
    } catch (_e) {
      this.renderResults([])
    }
  }

  renderResults(results) {
    const applied = new Set(this.appliedTagIdsValue)
    this.resultsTarget.innerHTML = ""
    this.highlightedIndex = -1

    if (results.length === 0) return

    results.forEach((item, index) => {
      const li = document.createElement("li")
      const isDisabled = applied.has(item.id)
      li.dataset.tagId = item.id
      li.dataset.tagName = item.text
      li.dataset.index = index
      li.textContent = item.text
      li.className = [
        "px-[14.4px] py-[6px] text-[12px] cursor-pointer",
        isDisabled ? "text-gray-400 cursor-not-allowed opacity-60" : "text-[#6c757d] hover:bg-[#2e6fe3] hover:text-white"
      ].join(" ")

      if (isDisabled) {
        li.setAttribute("aria-disabled", "true")
      } else {
        li.addEventListener("mousedown", (e) => {
          e.preventDefault()
          this.pick(index)
        })
        li.addEventListener("mouseenter", () => this.setHighlight(index))
      }

      this.resultsTarget.appendChild(li)
    })
  }

  setHighlight(index) {
    const items = this.resultsTarget.querySelectorAll("li")
    items.forEach((el) => {
      el.classList.remove("bg-[#2e6fe3]", "text-white")
      if (!el.hasAttribute("aria-disabled")) {
        el.classList.add("text-[#6c757d]")
      }
    })
    if (index < 0 || index >= items.length) {
      this.highlightedIndex = -1
      return
    }
    const target = items[index]
    if (target.hasAttribute("aria-disabled")) {
      this.highlightedIndex = -1
      return
    }
    target.classList.remove("text-[#6c757d]")
    target.classList.add("bg-[#2e6fe3]", "text-white")
    this.highlightedIndex = index
  }

  pick(index) {
    const item = this.currentResults[index]
    if (!item) return
    if (this.appliedTagIdsValue.includes(item.id)) return
    this.submitCreate(item.text)
  }

  keydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      if (this.highlightedIndex >= 0) {
        this.pick(this.highlightedIndex)
      } else {
        const value = this.inputTarget.value.trim()
        if (value.length === 0) return
        if (this.isAlreadyApplied(value)) {
          this.inputTarget.value = ""
          this.closeDropdown()
          return
        }
        this.submitCreate(value)
      }
    } else if (event.key === "ArrowDown") {
      event.preventDefault()
      this.moveHighlight(1)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.moveHighlight(-1)
    } else if (event.key === "Escape") {
      this.closeDropdown()
    } else if (event.key === "Backspace" && this.inputTarget.value.length === 0) {
      const pills = this.element.querySelectorAll("[data-tag-input-target='pill']")
      const last = pills[pills.length - 1]
      if (last) this.removeById(last.dataset.tagId)
    }
  }

  moveHighlight(direction) {
    const items = Array.from(this.resultsTarget.querySelectorAll("li"))
    if (items.length === 0) return

    let next = this.highlightedIndex
    for (let i = 0; i < items.length; i++) {
      next = (next + direction + items.length) % items.length
      if (!items[next].hasAttribute("aria-disabled")) {
        this.setHighlight(next)
        return
      }
    }
  }

  isAlreadyApplied(name) {
    const target = name.trim().toLowerCase()
    const pills = this.element.querySelectorAll("[data-tag-input-target='pill']")
    return Array.from(pills).some((pill) => {
      const label = pill.querySelector("span:last-child")
      return label && label.textContent.trim().toLowerCase() === target
    })
  }

  async submitCreate(name) {
    try {
      const body = `tag%5Bname%5D=${encodeURIComponent(name)}`
      const res = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": this.csrfValue
        },
        credentials: "same-origin",
        body
      })
      const text = await res.text()
      if (text) window.Turbo.renderStreamMessage(text)
      this.inputTarget.value = ""
      this.closeDropdown()
    } catch (_e) {
      this.showNetworkErrorToast()
    }
  }

  remove(event) {
    event.preventDefault()
    event.stopPropagation()
    const button = event.currentTarget
    const tagId = button.dataset.tagId
    if (tagId) this.removeById(tagId)
  }

  async removeById(tagId) {
    try {
      const url = this.destroyUrlTemplateValue.replace("__TAG_ID__", tagId)
      const res = await fetch(url, {
        method: "DELETE",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfValue
        },
        credentials: "same-origin"
      })
      const text = await res.text()
      if (text) window.Turbo.renderStreamMessage(text)
    } catch (_e) {
      this.showNetworkErrorToast()
    }
  }

  openDropdown() {
    this.dropdownTarget.classList.remove("hidden")
  }

  closeDropdown() {
    this.dropdownTarget.classList.add("hidden")
    this.highlightedIndex = -1
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.closeDropdown()
    }
  }

  showNetworkErrorToast() {
    const container = document.getElementById("admin_toast_container")
    if (!container) return
    const toast = document.createElement("div")
    toast.setAttribute("data-controller", "toast")
    toast.className = "w-80 bg-white border border-red-200 rounded-lg shadow-lg p-4 text-sm text-gray-900 transition-all duration-300 ease-in-out translate-x-full opacity-0"
    toast.textContent = "Network error. Please try again."
    container.appendChild(toast)
  }
}
