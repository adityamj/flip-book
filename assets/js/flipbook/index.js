function loadImage(img) {
  if (!img || img.src) {
    return
  }

  img.src = img.dataset.src
}

function isCompactFlipbookViewport() {
  return window.matchMedia("(max-width: 900px) and (pointer: coarse)").matches
}

function initThumbObserver(root, thumbImages) {
  if (!("IntersectionObserver" in window)) {
    thumbImages.forEach(loadImage)
    return
  }

  const thumbsPane = root.querySelector("[data-thumbs]")
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        loadImage(entry.target)
        observer.unobserve(entry.target)
      }
    })
  }, {
    root: thumbsPane,
    rootMargin: "200px 0px",
    threshold: 0.01,
  })

  thumbImages.forEach((image) => observer.observe(image))
}

async function initFlipbook(root) {
  const jsonUrl = root.dataset.jsonUrl
  if (!jsonUrl) {
    return
  }

  let data

  try {
    const response = await fetch(jsonUrl, { headers: { Accept: "application/json" } })

    if (!response.ok) {
      throw new Error(`Failed to load issue JSON: ${response.status}`)
    }

    data = await response.json()
  } catch (error) {
    const book = root.querySelector("[data-book]")
    book.textContent = "Flipbook data failed to load."
    book.classList.add("flipbook-book-empty")
    console.error(error)
    return
  }

  const items = Array.isArray(data.items) ? data.items : []
  const thumbsPane = root.querySelector("[data-thumbs]")
  const book = root.querySelector("[data-book]")
  const prevButton = root.querySelector("[data-prev]")
  const nextButton = root.querySelector("[data-next]")
  const thumbToggle = root.querySelector("[data-thumb-toggle]")
  const fullscreenToggle = root.querySelector("[data-fullscreen-toggle]")

  if (!items.length) {
    book.textContent = "No pages found for this issue."
    book.classList.add("flipbook-book-empty")
    console.error("Flipbook issue has no page resources", data)
    return
  }

  if (!window.St || !window.St.PageFlip) {
    book.textContent = "Flipbook viewer failed to load. Refresh the page and check the PageFlip script."
    book.classList.add("flipbook-book-empty")
    console.error("PageFlip library is missing")
    return
  }

  function updateFullscreenButton() {
    if (!fullscreenToggle) {
      return
    }

    const isFullscreen = document.fullscreenElement === root
    fullscreenToggle.textContent = isFullscreen ? "Exit full screen" : "View in full screen"
    fullscreenToggle.setAttribute("aria-label", isFullscreen ? "Exit full screen" : "View in full screen")
  }

  const pageElements = []
  const thumbImages = []
  let pageFlip
  let touchStartX = null
  let touchStartY = null

  function syncThumbState() {
    if (isCompactFlipbookViewport()) {
      thumbsPane.classList.add("is-collapsed")
    } else {
      thumbsPane.classList.remove("is-collapsed")
    }
  }

  function ensurePageImages(centerIndex) {
    const safeIndex = Number.isInteger(centerIndex) ? centerIndex : 0
    const start = Math.max(0, safeIndex - 2)
    const end = Math.min(pageElements.length - 1, safeIndex + 3)

    for (let index = start; index <= end; index += 1) {
      const image = pageElements[index].querySelector("img")
      loadImage(image)
    }
  }

  items.forEach((item, index) => {
    const thumb = document.createElement("img")
    thumb.dataset.src = item.thumb
    thumb.alt = item.label || `Page ${index + 1}`
    thumb.loading = "lazy"
    thumb.decoding = "async"
    thumb.addEventListener("click", () => {
      if (pageFlip) {
        pageFlip.flip(index)
      }

      if (isCompactFlipbookViewport()) {
        thumbsPane.classList.add("is-collapsed")
      }
    })
    thumbsPane.appendChild(thumb)
    thumbImages.push(thumb)

    const page = document.createElement("div")
    page.className = "flipbook-page"

    const pageImage = document.createElement("img")
    pageImage.dataset.src = item.page
    pageImage.alt = item.label || `Page ${index + 1}`
    pageImage.className = "flipbook-page-image"

    if (index <= 3) {
      loadImage(pageImage)
    }

    page.appendChild(pageImage)
    book.appendChild(page)
    pageElements.push(page)
  })

  initThumbObserver(root, thumbImages)

  const isCompactViewport = isCompactFlipbookViewport()

  pageFlip = new window.St.PageFlip(book, {
    size: "stretch",
    minWidth: 198,
    maxWidth: 707,
    minHeight: 350,
    maxHeight: 1000,
    width: 707,
    height: 1000,
    usePortrait: isCompactViewport,
    autoSize: true,
    showCover: data.showCover !== false,
    mobileScrollSupport: false,
  })

  pageFlip.loadFromHTML(pageElements)
  ensurePageImages(0)

  prevButton.addEventListener("click", () => pageFlip.flipPrev())
  nextButton.addEventListener("click", () => pageFlip.flipNext())
  thumbToggle.addEventListener("click", () => thumbsPane.classList.toggle("is-collapsed"))

  if (fullscreenToggle) {
    fullscreenToggle.addEventListener("click", async () => {
      try {
        if (document.fullscreenElement === root) {
          await document.exitFullscreen()
        } else {
          await root.requestFullscreen()
        }
      } catch (error) {
        console.error("Fullscreen toggle failed", error)
      }
    })

    document.addEventListener("fullscreenchange", updateFullscreenButton)
    updateFullscreenButton()
  }

  window.addEventListener("resize", syncThumbState)
  syncThumbState()

  window.addEventListener("keydown", (event) => {
    if (event.key === "ArrowLeft") {
      event.preventDefault()
      pageFlip.flipPrev()
    }

    if (event.key === "ArrowRight") {
      event.preventDefault()
      pageFlip.flipNext()
    }
  })

  book.addEventListener("touchstart", (event) => {
    const touch = event.changedTouches[0]
    touchStartX = touch.clientX
    touchStartY = touch.clientY
  }, { passive: true })

  book.addEventListener("touchend", (event) => {
    if (touchStartX === null || touchStartY === null) {
      return
    }

    const touch = event.changedTouches[0]
    const deltaX = touch.clientX - touchStartX
    const deltaY = touch.clientY - touchStartY

    touchStartX = null
    touchStartY = null

    if (Math.abs(deltaX) < 40 || Math.abs(deltaX) < Math.abs(deltaY)) {
      return
    }

    if (deltaX < 0) {
      pageFlip.flipNext()
    } else {
      pageFlip.flipPrev()
    }
  }, { passive: true })

  pageFlip.on("flip", (event) => {
    ensurePageImages(event.data)
  })
}

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-flipbook-root]").forEach(initFlipbook)
})
