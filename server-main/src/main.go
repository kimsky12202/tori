package main

import (
	"log"
	"net/http"
	"os"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/jsvm"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"
	"github.com/pocketbase/pocketbase/tools/hook"
)

func main() {
	app := pocketbase.New()

	// Enable JS migrations/hooks loading from pb_migrations/pb_hooks.
	jsvm.MustRegister(app, jsvm.Config{})

	// Register migrate command and use JS templates for new migration files.
	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{
		TemplateLang: migratecmd.TemplateLangJS,
	})

	// Test route to verify route registration works
	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Func: func(e *core.ServeEvent) error {
			e.Router.POST("/test", func(re *core.RequestEvent) error {
				return re.JSON(http.StatusOK, map[string]string{"message": "test route works"})
			})
			return e.Next()
		},
	})

	registerLoginRoute(app)
	registerRegisterRoute(app)
	registerVerificationRoute(app)
	registerChallengeRoutes(app)
	registerCapsuleRoutes(app) //캡슐
	registerGroupCapsulePushFeatures(app)
	registerFriendshipRoutes(app)
	registerTouristSpotRoutes(app) //관광지 탐험

	// If no args, run serve by default
	if len(os.Args) == 1 {
		os.Args = append(os.Args, "serve")
	}

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
