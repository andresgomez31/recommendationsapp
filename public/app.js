const cardsContainer = document.getElementById("cardsContainer");
const refreshBtn = document.getElementById("refreshBtn");
const recommendationForm = document.getElementById("recommendationForm");
const externalSourceForm = document.getElementById("externalSourceForm");
const clearExternalSourceBtn = document.getElementById("clearExternalSourceBtn");

function getExternalSource() {
  return {
    name: localStorage.getItem("externalSourceName"),
    url: localStorage.getItem("externalSourceUrl")
  };
}

function showToast() {
  const toastElement = document.getElementById("errorToast");
  const toast = new bootstrap.Toast(toastElement);
  toast.show();
}

function renderCards(recommendations) {
  cardsContainer.innerHTML = "";

  recommendations.forEach(item => {
    const col = document.createElement("div");
    col.className = "col-md-6 col-lg-4 mb-4";

    const deleteButton = item.source === "Local"
      ? `<button class="btn btn-sm btn-outline-danger mt-3" onclick="deleteLocalRecommendation(${item.id})">Delete</button>`
      : "";

    const image = item.image_url
      ? `<img src="${item.image_url}" class="card-img-top" style="height:200px; object-fit:cover;">`
      : `<div class="card-img-top d-flex align-items-center justify-content-center bg-dark text-white" style="height:200px;">
           🎬
         </div>`;

    col.innerHTML = `
      <div class="card h-100 shadow-sm">
        ${image}
        <div class="card-body">
          <div class="d-flex justify-content-between align-items-start mb-2">
            <h5 class="card-title mb-0">${item.title}</h5>
            <span class="badge text-bg-secondary">${item.source}</span>
          </div>
          <p class="mb-1"><strong>Type:</strong> ${item.type}</p>
          <p class="mb-1"><strong>Genre:</strong> ${item.genre}</p>
          <p class="mb-1"><strong>Year:</strong> ${item.year || ""}</p>
          <p class="mb-1"><strong>Rating:</strong> ${item.rating}/5</p>
          <p class="card-text mt-3">${item.comment}</p>
          ${deleteButton}
        </div>
      </div>
    `;

    cardsContainer.appendChild(col);
  });
}

async function loadRecommendations() {
  const allRecommendations = [];

  const localResponse = await fetch("/api/recommendations");
  const localRecommendations = await localResponse.json();

  localRecommendations.forEach(item => {
    allRecommendations.push({
      ...item,
      source: "Local"
    });
  });

  const external = getExternalSource();

  if (external.url && external.name) {
    try {
      const externalResponse = await fetch(`${external.url}/api/recommendations`);
      const externalRecommendations = await externalResponse.json();

      externalRecommendations.forEach(item => {
        allRecommendations.push({
          ...item,
          source: external.name
        });
      });
    } catch (error) {
      showToast();
    }
  }

  renderCards(allRecommendations);
}

async function deleteLocalRecommendation(id) {
  await fetch(`/api/recommendations/${id}`, {
    method: "DELETE"
  });

  loadRecommendations();
}

recommendationForm.addEventListener("submit", async (event) => {
  event.preventDefault();

  const payload = {
    title: document.getElementById("title").value,
    type: document.getElementById("type").value,
    genre: document.getElementById("genre").value,
    year: document.getElementById("year").value || null,
    comment: document.getElementById("comment").value,
    rating: parseInt(document.getElementById("rating").value, 10),
    image_url: document.getElementById("image_url").value || null
  };

  await fetch("/api/recommendations", {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(payload)
  });

  recommendationForm.reset();
  bootstrap.Modal.getInstance(document.getElementById("addRecommendationModal")).hide();
  loadRecommendations();
});

externalSourceForm.addEventListener("submit", (event) => {
  event.preventDefault();

  localStorage.setItem("externalSourceName", document.getElementById("externalSourceName").value);
  localStorage.setItem("externalSourceUrl", document.getElementById("externalSourceUrl").value);

  bootstrap.Modal.getInstance(document.getElementById("externalSourceModal")).hide();
  loadRecommendations();
});

clearExternalSourceBtn.addEventListener("click", () => {
  localStorage.removeItem("externalSourceName");
  localStorage.removeItem("externalSourceUrl");

  document.getElementById("externalSourceName").value = "";
  document.getElementById("externalSourceUrl").value = "";

  bootstrap.Modal.getInstance(document.getElementById("externalSourceModal")).hide();
  loadRecommendations();
});

refreshBtn.addEventListener("click", loadRecommendations);

loadRecommendations();
